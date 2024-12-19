require "rails_helper"

describe Coordinators::Actions do
  let(:app) { create(:app, :android) }
  let(:config) {
    {
      workflows: {
        internal: nil,
        release_candidate: {
          name: Faker::FunnyName.name,
          id: Faker::Number.number(digits: 8),
          artifact_name_pattern: nil,
          kind: "release_candidate"
        }
      },
      internal_release: nil,
      beta_release: {
        auto_promote: false,
        submissions: [
          {
            number: 1,
            submission_type: "PlayStoreSubmission",
            submission_config: {id: Faker::FunnyName.name, name: Faker::FunnyName.name, is_internal: true},
            integrable_id: app.id,
            integrable_type: "App"
          }
        ]
      },
      production_release: {
        auto_promote: false,
        submissions: [
          {
            number: 1,
            submission_type: "PlayStoreSubmission",
            submission_config: GooglePlayStoreIntegration::PROD_CHANNEL,
            rollout_config: {enabled: true, stages: [1, 5, 10, 50, 100]},
            integrable_id: app.id,
            integrable_type: "App"
          }
        ]
      }
    }
  }
  let(:release) { create(:release, :on_track, is_v2: true) }
  let(:release_platform_run) { create(:release_platform_run, :on_track, release:) }

  describe ".start_workflow_run!" do
    let(:beta_release) { create(:beta_release, release_platform_run:) }
    let(:workflow_run) { create(:workflow_run, :rc, release_platform_run:, triggering_release: beta_release) }

    it "returns error if release platform run is not on track" do
      release_platform_run.update!(status: "stopped")
      result = described_class.start_workflow_run!(workflow_run)
      expect(result).not_to be_ok
      expect(result.error.message).to eq("release is not actionable")
      expect(workflow_run.reload.created?).to be(true)
    end

    it "initiates the workflow run" do
      expect {
        result = described_class.start_workflow_run!(workflow_run)
        expect(result).to be_ok
        expect(workflow_run.reload.triggering?).to be(true)
      }.to change(WorkflowRuns::TriggerJob.jobs, :size).by(1)

      expect(WorkflowRuns::TriggerJob.jobs.last["args"]).to eq([workflow_run.id])
    end
  end

  describe ".retry_workflow_run!" do
    let(:beta_release) { create(:beta_release, release_platform_run:) }
    let(:workflow_run) { create(:workflow_run, :rc, :failed, release_platform_run:, triggering_release: beta_release) }

    it "returns error if release platform run is not on track" do
      release_platform_run.update!(status: "stopped")
      result = described_class.retry_workflow_run!(workflow_run)
      expect(result).not_to be_ok
      expect(result.error.message).to eq("release is not actionable")
      expect(workflow_run.reload.failed?).to be(true)
    end

    it "retries the workflow run" do
      expect {
        result = described_class.retry_workflow_run!(workflow_run)
        expect(result).to be_ok
        expect(workflow_run.reload.triggering?).to be(true)
      }.to change(WorkflowRuns::TriggerJob.jobs, :size).by(1)

      expect(WorkflowRuns::TriggerJob.jobs.last["args"]).to eq([workflow_run.id, {"retrigger" => true}])
    end
  end

  describe ".start_internal_release!" do
    it "returns error if release platform run is not on track" do
      release_platform_run.update!(status: "stopped")
      result = described_class.start_internal_release!(release_platform_run)
      expect(result).not_to be_ok
      expect(result.error.message).to eq("release is not active")
      expect(release_platform_run.reload.internal_releases.size).to eq(0)
    end

    it "starts the internal release for the last applicable commit" do
      allow(Coordinators::CreateInternalRelease).to receive(:call)
      commit = create(:commit, release:)
      result = described_class.start_internal_release!(release_platform_run)
      expect(result).to be_ok
      expect(Coordinators::CreateInternalRelease).to have_received(:call).with(release_platform_run, commit).once
    end
  end

  describe ".start_beta_release!" do
    it "returns error if release platform run is not on track" do
      release_platform_run.update!(status: "stopped")
      result = described_class.start_beta_release!(release_platform_run)
      expect(result).not_to be_ok
      expect(result.error.message).to eq("release is not active")
      expect(release_platform_run.reload.beta_releases.size).to eq(0)
    end

    it "starts the beta release for the last applicable commit" do
      allow(Coordinators::CreateBetaRelease).to receive(:call)
      commit = create(:commit, release:)
      result = described_class.start_beta_release!(release_platform_run)
      expect(result).to be_ok
      expect(Coordinators::CreateBetaRelease).to have_received(:call).with(release_platform_run, commit).once
    end
  end

  describe ".trigger_submission!" do
    let(:beta_release) { create(:beta_release, release_platform_run:) }
    let(:workflow_run) { create(:workflow_run, :rc, :failed, release_platform_run:, triggering_release: beta_release) }
    let(:build) { create(:build, release_platform_run:, workflow_run:) }
    let(:submission) { create(:play_store_submission, parent_release: beta_release, build:) }

    it "returns error if release platform run is not on track" do
      release_platform_run.update!(status: "stopped")
      result = described_class.trigger_submission!(submission)
      expect(result).not_to be_ok
      expect(result.error.message).to eq("submission is not triggerable")
    end

    it "returns error if submission is not triggerable" do
      submission.update!(status: "prepared")
      result = described_class.trigger_submission!(submission)
      expect(result).not_to be_ok
      expect(result.error.message).to eq("submission is not triggerable")
    end

    it "triggers the submission" do
      expect {
        result = described_class.trigger_submission!(submission)
        expect(result).to be_ok
        expect(submission.reload.preprocessing?).to be(true)
      }.to change(StoreSubmissions::PlayStore::UploadJob.jobs, :size).by(1)

      expect(StoreSubmissions::PlayStore::UploadJob.jobs.last["args"]).to eq([submission.id])
    end
  end

  describe ".retry_submission!" do
    let(:beta_release) { create(:beta_release, release_platform_run:) }
    let(:workflow_run) { create(:workflow_run, :rc, :failed, release_platform_run:, triggering_release: beta_release) }
    let(:build) { create(:build, release_platform_run:, workflow_run:) }
    let(:submission) { create(:play_store_submission, :failed_with_action_required, parent_release: beta_release, build:) }

    it "returns error if release platform run is not on track" do
      release_platform_run.update!(status: "stopped")
      result = described_class.retry_submission!(submission)
      expect(result).not_to be_ok
      expect(result.error.message).to eq("submission is not actionable")
    end

    it "returns error if submission is not retryable" do
      submission.update!(status: "prepared")
      result = described_class.retry_submission!(submission)
      expect(result).not_to be_ok
      expect(result.error.message).to eq("submission is not retryable")
    end

    it "retries the submission" do
      providable_dbl = instance_double(GooglePlayStoreIntegration)
      allow(submission).to receive(:provider).and_return(providable_dbl)
      allow(providable_dbl).to receive(:public_icon_img)
      allow(providable_dbl).to receive(:project_link)
      allow(providable_dbl).to receive(:build_present_in_channel?).and_return(true)

      result = described_class.retry_submission!(submission)
      expect(result).to be_ok
      expect(submission.reload.status).to eq("finished_manually")
    end
  end
end
