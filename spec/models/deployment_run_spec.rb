require "rails_helper"

describe DeploymentRun, type: :model do
  it "has a valid factory" do
    expect(create(:deployment_run)).to be_valid
  end

  describe "#start_upload!" do
    let(:step) { create(:releases_step, :with_deployment) }
    let(:step_run) { create(:releases_step_run, :deployment_started, step: step) }

    it "marks as completed if deployment is external" do
      external_deployment = create(:deployment, step: step, integration: nil)
      deployment_run = create(:deployment_run, :started, deployment: external_deployment, step_run: step_run)

      deployment_run.start_upload!
      expect(deployment_run.reload.released?).to be(true)
    end

    it "marks as uploaded if there is another similar deployment which has uploaded" do
      integration = create(:integration, :with_google_play_store)
      deployment1 = create(:deployment, step: step, integration: integration)
      deployment2 = create(:deployment, step: step, integration: integration)
      _uploaded_run = create(:deployment_run, :uploaded, deployment: deployment1, step_run: step_run)
      deployment_run = create(:deployment_run, :started, deployment: deployment2, step_run: step_run)

      deployment_run.start_upload!
      expect(deployment_run.reload.uploaded?).to be(true)
    end

    it "starts upload if there is another similar deployment but not store" do
      integration = create(:integration, :with_slack)
      deployment1 = create(:deployment, step: step, integration: integration)
      deployment2 = create(:deployment, step: step, integration: integration)
      _uploaded_run = create(:deployment_run, :uploaded, deployment: deployment1, step_run: step_run)
      deployment_run = create(:deployment_run, :started, deployment: deployment2, step_run: step_run)
      allow(Deployments::Slack).to receive(:perform_later)

      deployment_run.start_upload!
      expect(Deployments::Slack).to have_received(:perform_later).with(deployment_run.id).once
      expect(deployment_run.reload.started?).to be(true)
    end

    it "does nothing if there is another similar deployment which has started upload" do
      integration = create(:integration)
      deployment1 = create(:deployment, step: step, integration: integration)
      deployment2 = create(:deployment, step: step, integration: integration)
      _ignored_run = create(:deployment_run, :started, deployment: deployment1, step_run: step_run)
      deployment_run = create(:deployment_run, :started, deployment: deployment2, step_run: step_run)

      deployment_run.start_upload!
      expect(deployment_run.reload.started?).to be(true)
    end

    it "starts upload if it is the only deployment with google play store" do
      deployment = create(:deployment, :with_google_play_store, step: step)
      deployment_run = create(:deployment_run, :started, deployment: deployment, step_run: step_run)
      allow(Deployments::GooglePlayStore::Upload).to receive(:perform_later)

      deployment_run.start_upload!

      expect(Deployments::GooglePlayStore::Upload).to have_received(:perform_later).with(deployment_run.id).once
      expect(deployment_run.reload.started?).to be(true)
    end

    it "starts upload if it is the only deployment with slack" do
      deployment = create(:deployment, :with_slack, step: step)
      deployment_run = create(:deployment_run, :started, deployment: deployment, step_run: step_run)
      allow(Deployments::Slack).to receive(:perform_later)

      deployment_run.start_upload!
      expect(Deployments::Slack).to have_received(:perform_later).with(deployment_run.id).once
      expect(deployment_run.reload.started?).to be(true)
    end

    it "starts upload if a different deployment has happened before" do
      deployment1 = create(:deployment, step: step)
      _ignored_run = create(:deployment_run, :released, deployment: deployment1, step_run: step_run)

      deployment2 = create(:deployment, :with_google_play_store, step: step)
      deployment_run = create(:deployment_run, :started, deployment: deployment2, step_run: step_run)

      allow(Deployments::GooglePlayStore::Upload).to receive(:perform_later)

      deployment_run.start_upload!
      expect(Deployments::GooglePlayStore::Upload).to have_received(:perform_later).with(deployment_run.id).once
      expect(deployment_run.reload.started?).to be(true)
    end
  end

  describe "#upload!" do
    let(:step) { create(:releases_step, :with_deployment) }
    let(:step_run) { create(:releases_step_run, :deployment_started, step: step) }

    it "marks self as uploaded" do
      deployment = create(:deployment, step: step)
      deployment_run = create(:deployment_run, :started, deployment: deployment, step_run: step_run)

      deployment_run.upload!

      expect(deployment_run.reload.uploaded?).to be(true)
    end

    it "marks other similar deployments in the step run as uploaded" do
      integration = create(:integration, :with_google_play_store)
      deployment1 = create(:deployment, step: step, integration: integration)
      similar_run = create(:deployment_run, :started, deployment: deployment1, step_run: step_run)
      deployment2 = create(:deployment, step: step, integration: integration)
      deployment_run = create(:deployment_run, :started, deployment: deployment2, step_run: step_run)

      deployment_run.upload!

      expect(similar_run.reload.uploaded?).to be(true)
      expect(deployment_run.reload.uploaded?).to be(true)
    end

    it "ignores other similar deployments in the step run if already uploaded" do
      integration = create(:integration, :with_google_play_store)
      deployment1 = create(:deployment, step: step, integration: integration)
      similar_uploaded_run = create(:deployment_run, :uploaded, deployment: deployment1, step_run: step_run)
      deployment2 = create(:deployment, step: step, integration: integration)
      deployment_run = create(:deployment_run, :started, deployment: deployment2, step_run: step_run)

      deployment_run.upload!

      expect(similar_uploaded_run.reload.uploaded?).to be(true)
      expect(deployment_run.reload.uploaded?).to be(true)
    end

    it "ignores other similar deployments in the step run if not store" do
      integration = create(:integration, :with_slack)
      deployment1 = create(:deployment, step: step, integration: integration)
      similar_run = create(:deployment_run, :started, deployment: deployment1, step_run: step_run)
      deployment2 = create(:deployment, step: step, integration: integration)
      deployment_run = create(:deployment_run, :started, deployment: deployment2, step_run: step_run)

      deployment_run.upload!

      expect(similar_run.reload.started?).to be(true)
      expect(deployment_run.reload.uploaded?).to be(true)
    end
  end
end
