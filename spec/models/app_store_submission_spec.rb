require "rails_helper"

describe AppStoreSubmission do
  it "has a valid factory" do
    expect(create(:app_store_submission)).to be_valid
  end

  describe "#startable?" do
    it "returns false if there is no build associated" do
      submission = create(:app_store_submission)
      expect(submission).not_to be_startable
    end

    it "returns true if there is a build associated" do
      submission = create(:app_store_submission, :with_build)
      expect(submission).to be_startable
    end
  end

  describe ".prepare_for_release!" do
    let(:providable_dbl) { instance_double(AppStoreIntegration) }
    let(:build) { create(:build) }
    let(:submission) { create(:app_store_submission, :preparing, build:) }
    let(:base_release_info) {
      {
        external_id: "bd31faa6-6a9a-4958-82de-d271ddc639a8",
        name: build.version_name,
        build_number: build.build_number,
        added_at: 1.day.ago,
        phased_release_status: "INACTIVE",
        phased_release_day: 0
      }
    }

    before do
      allow_any_instance_of(described_class).to receive(:provider).and_return(providable_dbl)
      allow(providable_dbl).to receive(:public_icon_img)
      allow(providable_dbl).to receive(:project_link)
    end

    context "when successful" do
      let(:prepared_release_info) { AppStoreIntegration::AppStoreReleaseInfo.new(base_release_info.merge(status: "PREPARE_FOR_SUBMISSION")) }

      before do
        allow(providable_dbl).to receive(:prepare_release).and_return(GitHub::Result.new { prepared_release_info })
      end

      it "prepares the release" do
        submission.prepare_for_release!

        release_metadatum = submission.release_platform_run.release_metadatum
        expect(providable_dbl).to have_received(:prepare_release).with(build.build_number, build.version_name, true, release_metadatum, false).once
      end

      it "marks the submission as prepared" do
        submission.prepare_for_release!

        expect(submission.reload.prepared?).to be(true)
        expect(submission.reload.prepared_at).to be_present
      end

      it "prepares the release with force" do
        submission.prepare_for_release!(force: true)

        release_metadatum = submission.release_platform_run.release_metadatum
        expect(providable_dbl).to have_received(:prepare_release).with(build.build_number, build.version_name, true, release_metadatum, true).once
      end
    end

    context "when failure" do
      let(:error) { Installations::Apple::AppStoreConnect::Error.new({"error" => {"resource" => "build", "code" => "not_found"}}) }

      before do
        allow(providable_dbl).to receive(:prepare_release).and_return(GitHub::Result.new { raise error })
      end

      it "marks the submission as failed when failure" do
        submission.prepare_for_release!

        expect(submission.reload.failed?).to be(true)
      end

      it "adds the reason of failure to submission" do
        submission.prepare_for_release!

        expect(submission.reload.failure_reason).to eq("build_not_found")
      end
    end

    context "when retryable failure" do
      let(:error) { Installations::Apple::AppStoreConnect::Error.new({"error" => {"resource" => "release", "code" => "release_already_prepared"}}) }

      before do
        allow(providable_dbl).to receive(:prepare_release).and_return(GitHub::Result.new { raise error })
      end

      it "marks the deployment run as failed to prepare release" do
        submission.prepare_for_release!

        expect(submission.reload.failed_prepare?).to be(true)
      end

      it "adds the reason of failure to deployment run" do
        submission.prepare_for_release!

        expect(submission.reload.failure_reason).to eq("release_already_exists")
      end
    end

    context "when invalid release" do
      it "marks the submission as failed when invalid release due to version name mismatch" do
        invalid_release_info = AppStoreIntegration::AppStoreReleaseInfo.new(base_release_info.merge(
          {status: "PREPARE_FOR_SUBMISSION",
           name: "invalid"}
        ))
        allow(providable_dbl).to receive(:prepare_release).and_return(GitHub::Result.new { invalid_release_info })
        submission.prepare_for_release!

        expect(submission.reload.failed?).to be(true)
      end

      it "marks the submission as failed when invalid release due to build number mismatch" do
        invalid_release_info = AppStoreIntegration::AppStoreReleaseInfo.new(base_release_info.merge(
          {status: "PREPARE_FOR_SUBMISSION",
           build_number: 123}
        ))
        allow(providable_dbl).to receive(:prepare_release).and_return(GitHub::Result.new { invalid_release_info })
        submission.prepare_for_release!

        expect(submission.reload.failed?).to be(true)
      end

      it "marks the submission as failed when invalid release due to staged rollout mismatch" do
        invalid_release_info = AppStoreIntegration::AppStoreReleaseInfo.new(base_release_info.merge(
          {status: "PREPARE_FOR_SUBMISSION",
           phased_release_status: nil}
        ))
        allow(providable_dbl).to receive(:prepare_release).and_return(GitHub::Result.new { invalid_release_info })
        submission.prepare_for_release!

        expect(submission.reload.failed?).to be(true)
      end

      it "adds the reason of failure to submission" do
        invalid_release_info = AppStoreIntegration::AppStoreReleaseInfo.new(base_release_info.merge(
          {status: "PREPARE_FOR_SUBMISSION",
           build_number: 123}
        ))
        allow(providable_dbl).to receive(:prepare_release).and_return(GitHub::Result.new { invalid_release_info })
        submission.prepare_for_release!

        expect(submission.reload.failure_reason).to eq("invalid_release")
      end
    end
  end

  describe ".submit!" do
    let(:build) { create(:build) }
    let(:submission) { create(:app_store_submission, :prepared, build:) }
    let(:providable_dbl) { instance_double(AppStoreIntegration) }

    before do
      allow_any_instance_of(described_class).to receive(:provider).and_return(providable_dbl)
      allow(providable_dbl).to receive(:public_icon_img)
      allow(providable_dbl).to receive(:project_link)
    end

    context "when successful" do
      before do
        allow(providable_dbl).to receive(:submit_release).and_return(GitHub::Result.new)
      end

      it "submits the release" do
        submission.submit!

        expect(providable_dbl).to have_received(:submit_release).with(build.build_number, build.version_name).once
      end

      it "marks the submission as submitted" do
        submission.submit!

        expect(submission.reload.submitted_for_review?).to be(true)
      end
    end

    context "when failure" do
      let(:error) { Installations::Apple::AppStoreConnect::Error.new({"error" => {"resource" => "build", "code" => "not_found"}}) }
      let(:retryable_error) { Installations::Apple::AppStoreConnect::Error.new({"error" => {"resource" => "release", "code" => "attachment_upload_in_progress"}}) }

      before do
        allow(providable_dbl).to receive(:submit_release).and_return(GitHub::Result.new { raise error })
      end

      it "marks the submission as failed when failure" do
        allow(providable_dbl).to receive(:submit_release).and_return(GitHub::Result.new { raise error })
        submission.submit!

        expect(submission.reload.failed?).to be(true)
      end

      it "adds the reason of failure to submission" do
        allow(providable_dbl).to receive(:submit_release).and_return(GitHub::Result.new { raise error })
        submission.submit!

        expect(submission.reload.failure_reason).to eq("build_not_found")
      end

      it "does not mark the submission as failed when the failure is retryable" do
        allow(providable_dbl).to receive(:submit_release).and_return(GitHub::Result.new { raise retryable_error })
        submission.submit!

        expect(submission.reload.failed?).to be(false)
        expect(submission.reload.failure_reason).to eq("attachment_upload_in_progress")
      end
    end
  end

  describe ".update_external_release" do
    let(:build) { create(:build) }
    let(:submission) { create(:app_store_submission, :submitted_for_review, build:) }
    let(:providable_dbl) { instance_double(AppStoreIntegration) }
    let(:base_release_info) {
      {
        external_id: "bd31faa6-6a9a-4958-82de-d271ddc639a8",
        name: "1.2.0",
        build_number: "123",
        added_at: 1.day.ago,
        phased_release_status: "INACTIVE",
        phased_release_day: 0
      }
    }
    let(:initial_release_info) { AppStoreIntegration::AppStoreReleaseInfo.new(base_release_info.merge(status: "WAITING_FOR_REVIEW")) }
    let(:in_progress_release_info) { AppStoreIntegration::AppStoreReleaseInfo.new(base_release_info.merge(status: "IN_REVIEW")) }
    let(:success_release_info) { AppStoreIntegration::AppStoreReleaseInfo.new(base_release_info.merge(status: "PENDING_DEVELOPER_RELEASE")) }
    let(:rejected_release_info) { AppStoreIntegration::AppStoreReleaseInfo.new(base_release_info.merge(status: "REJECTED")) }
    let(:cancelled_release_info) { AppStoreIntegration::AppStoreReleaseInfo.new(base_release_info.merge(status: "DEVELOPER_REJECTED")) }

    before do
      allow_any_instance_of(described_class).to receive(:provider).and_return(providable_dbl)
      allow(providable_dbl).to receive(:public_icon_img)
      allow(providable_dbl).to receive(:project_link)
    end

    it "finds release" do
      allow(providable_dbl).to receive(:find_release).and_return(GitHub::Result.new { initial_release_info })

      expect { submission.update_external_release }
        .to raise_error(AppStoreSubmission::ExternalReleaseNotInTerminalState)

      expect(providable_dbl).to have_received(:find_release).with(build.build_number).once
    end

    it "updates store status" do
      allow(providable_dbl).to receive(:find_release).and_return(GitHub::Result.new { in_progress_release_info })

      expect { submission.update_external_release }
        .to raise_error(AppStoreSubmission::ExternalReleaseNotInTerminalState)

      expect(submission.reload.store_status).to eq("IN_REVIEW")
    end

    it "marks submission as approved if review is successful" do
      allow(providable_dbl).to receive(:find_release).and_return(GitHub::Result.new { success_release_info })

      submission.update_external_release

      expect(submission.reload.approved?).to be(true)
    end

    it "marks the submission as rejected when rejected" do
      allow(providable_dbl).to receive(:find_release).and_return(GitHub::Result.new { rejected_release_info })

      expect { submission.update_external_release }
        .to raise_error(AppStoreSubmission::ExternalReleaseNotInTerminalState)

      expect(submission.reload.review_failed?).to be(true)
    end

    it "marks the submission as submitted for review when a rejected release is resubmitted" do
      submission.reject!
      allow(providable_dbl).to receive(:find_release).and_return(GitHub::Result.new { in_progress_release_info })

      submission.update_external_release

      expect(submission.reload.submitted_for_review?).to be(true)
    end

    it "marks the submission as cancelled when review is cancelled" do
      allow(providable_dbl).to receive(:find_release).and_return(GitHub::Result.new { cancelled_release_info })

      submission.update_external_release

      expect(submission.reload.cancelled?).to be(true)
    end

    it "raises error to re-poll when find build fails" do
      error = Installations::Apple::AppStoreConnect::Error.new({"error" => {"resource" => "build", "code" => "not_found"}})
      allow(providable_dbl).to receive(:find_release).and_return(GitHub::Result.new { raise(error) })

      expect { submission.update_external_release }
        .to raise_error(AppStoreSubmission::ExternalReleaseNotInTerminalState)

      expect(submission.reload.failed?).to be(false)
    end
  end
end
