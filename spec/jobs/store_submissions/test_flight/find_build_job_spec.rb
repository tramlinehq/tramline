require "rails_helper"

describe StoreSubmissions::TestFlight::FindBuildJob do
  describe "#perform" do
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
    let(:test_flight_submission) {
      create(:test_flight_submission,
        :preprocessing,
        parent_release: internal_release,
        config: {submission_config: {id: "123", name: "External Testers", is_internal: false}})
    }

    before do
      allow(provider_dbl).to receive(:release_to_testflight).and_return(GitHub::Result.new { build_info })
      allow_any_instance_of(TestFlightSubmission).to receive(:provider).and_return(provider_dbl)
      allow(Coordinators::Signals).to receive(:internal_release_finished!)
    end

    it "starts preparing the release when build is present in the store" do
      allow(provider_dbl).to receive(:find_build).and_return(GitHub::Result.new { build_info })

      described_class.new.perform(test_flight_submission.id)

      expect(test_flight_submission.reload.submitted_for_review?).to be true
      expect(provider_dbl).to have_received(:release_to_testflight)
        .with(test_flight_submission.submission_channel_id, test_flight_submission.build_number).once
    end

    it "handles build_not_found error and schedules a retry if retries are available" do
      build_not_found_error = Installations::Apple::AppStoreConnect::Error.new({"error" => {"code" => "not_found", "resource" => "build"}})
      allow(provider_dbl).to receive(:find_build).and_return(GitHub::Result.new { raise build_not_found_error })

      allow(described_class).to receive(:perform_in)

      described_class.new.perform(test_flight_submission.id)

      expect(described_class).to have_received(:perform_in).with(
        60.seconds,
        test_flight_submission.id,
        1
      )
    end

    it "does nothing if release is not on track" do
      internal_release.release_platform_run.update(status: "finished")

      described_class.new.perform(test_flight_submission.id)

      expect(test_flight_submission.reload.preprocessing?).to be true
    end
  end
end
