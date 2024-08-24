# frozen_string_literal: true

require "rails_helper"

describe TestFlightSubmission do
  let(:base_build_info) {
    {
      external_id: "bd31faa6-6a9a-4958-82de-d271ddc639a8",
      name: "1.2.0",
      build_number: "123",
      added_at: "2023-02-25T03:02:46-08:00"
    }
  }
  let(:workflow_run) { create(:workflow_run, :finished) }
  let(:internal_release) {
    create(:internal_release,
      config: {submissions: [{id: "123", name: "Internal Testers", is_internal: true}]},
      triggered_workflow_run: workflow_run,
      release_platform_run: workflow_run.release_platform_run,
      commit: workflow_run.commit)
  }
  let(:provider_dbl) { instance_double(AppStoreIntegration) }
  let(:build_info) { AppStoreIntegration::TestFlightInfo.new(base_build_info.merge(status: "WAITING_FOR_BETA_REVIEW")) }

  before do
    allow_any_instance_of(described_class).to receive(:provider).and_return(provider_dbl)
    allow(Coordinators::Signals).to receive(:internal_release_finished!)
  end

  it "has a valid factory" do
    expect(create(:test_flight_submission)).to be_valid
  end

  describe ".trigger!" do
    let(:test_flight_submission) {
      create(:test_flight_submission,
        parent_release: internal_release,
        config: {submission_config: {id: "123", name: "External Testers", is_internal: false}})
    }

    before do
      allow(provider_dbl).to receive(:release_to_testflight).and_return(GitHub::Result.new { build_info })
      allow(provider_dbl).to receive(:update_release_notes)
      allow(StoreSubmissions::TestFlight::FindBuildJob).to receive(:perform_async)
    end

    it "starts preparing the release when build is present in the store" do
      allow(provider_dbl).to receive(:find_build).and_return(GitHub::Result.new { build_info })

      test_flight_submission.trigger!

      expect(test_flight_submission.submitted_for_review?).to be true
      expect(provider_dbl).to have_received(:release_to_testflight)
        .with(test_flight_submission.submission_channel_id, test_flight_submission.build_number).once
    end

    it "find the build when build is not present in the store" do
      allow(provider_dbl).to receive(:find_build)
        .and_return(GitHub::Result.new { raise Installations::Error.new("build not found", reason: :build_not_found) })

      test_flight_submission.trigger!

      expect(test_flight_submission.preprocessing?).to be true
      expect(StoreSubmissions::TestFlight::FindBuildJob).to have_received(:perform_async).with(test_flight_submission.id).once
    end
  end

  describe ".start_release!" do
    context "when internal channel" do
      let(:test_flight_submission) {
        create(:test_flight_submission,
          parent_release: internal_release,
          config: {
            submission_config: {
              id: "123",
              name: "Internal Testers",
              is_internal: true
            }
          })
      }

      before do
        allow(provider_dbl).to receive(:update_release_notes)
        allow(provider_dbl).to receive(:find_build).and_return(GitHub::Result.new { build_info })
      end

      it "updates the build notes" do
        test_flight_submission.start_release!
        expect(provider_dbl).to have_received(:update_release_notes)
      end

      it "finishes the release" do
        test_flight_submission.start_release!
        expect(test_flight_submission.finished?).to be true
      end

      it "updates the store info" do
        test_flight_submission.start_release!

        expect(test_flight_submission.reload.store_release).to eq(build_info.build_info.with_indifferent_access)
        expect(test_flight_submission.reload.store_status).to eq("WAITING_FOR_BETA_REVIEW")
      end
    end

    context "when external channel" do
      let(:test_flight_submission) { create(:test_flight_submission, parent_release: internal_release) }

      before do
        allow(provider_dbl).to receive(:update_release_notes)
        allow(provider_dbl).to receive(:find_build).and_return(GitHub::Result.new { build_info })
        allow(provider_dbl).to receive(:release_to_testflight).and_return(GitHub::Result.new { build_info })
        allow(StoreSubmissions::TestFlight::UpdateExternalBuildJob).to receive(:perform_async)
      end

      it "updates the build notes" do
        test_flight_submission.start_release!

        expect(provider_dbl).to have_received(:update_release_notes)
      end

      it "sends the build to configured test group" do
        test_flight_submission.start_release!

        expect(provider_dbl).to have_received(:release_to_testflight).with(test_flight_submission.submission_channel_id,
          test_flight_submission.build_number)
      end

      it "submits for review" do
        test_flight_submission.start_release!

        expect(test_flight_submission.submitted_for_review?).to be true
      end

      it "starts find external build job" do
        test_flight_submission.start_release!

        expect(StoreSubmissions::TestFlight::UpdateExternalBuildJob).to have_received(:perform_async).with(test_flight_submission.id)
      end
    end
  end

  describe ".update_external_release" do
    let(:test_flight_submission) { create(:test_flight_submission, :submitted_for_review, parent_release: internal_release) }
    let(:in_progress_build_info) { AppStoreIntegration::TestFlightInfo.new(base_build_info.merge(status: "IN_BETA_REVIEW")) }
    let(:success_build_info) { AppStoreIntegration::TestFlightInfo.new(base_build_info.merge(status: "BETA_APPROVED")) }
    let(:rejected_build_info) { AppStoreIntegration::TestFlightInfo.new(base_build_info.merge(status: "BETA_REJECTED")) }

    before do
      allow(provider_dbl).to receive(:find_build).and_return(GitHub::Result.new { in_progress_build_info })
    end

    it "raises error when build is not in terminal state" do
      expect { test_flight_submission.update_external_release }.to raise_error(TestFlightSubmission::SubmissionNotInTerminalState)
    end

    it "updates the store info" do
      expect { test_flight_submission.update_external_release }.to raise_error(TestFlightSubmission::SubmissionNotInTerminalState)

      expect(test_flight_submission.reload.store_release).to eq(in_progress_build_info.build_info.with_indifferent_access)
      expect(test_flight_submission.reload.store_status).to eq("IN_BETA_REVIEW")
    end

    it "finishes the release when build is successful" do
      allow(provider_dbl).to receive(:find_build).and_return(GitHub::Result.new { success_build_info })
      test_flight_submission.update_external_release

      expect(test_flight_submission.finished?).to be true
    end

    it "rejects the release when build is rejected" do
      allow(provider_dbl).to receive(:find_build).and_return(GitHub::Result.new { rejected_build_info })

      test_flight_submission.update_external_release

      expect(test_flight_submission.review_failed?).to be true
    end
  end
end
