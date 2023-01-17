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

  describe "#upload_to_playstore!" do
    let(:slack_deployment_run) { create(:deployment_run, :started, :with_slack) }
    let(:store_deployment_run) { create(:deployment_run, :started, :with_google_play_store) }

    it "does nothing if deployment is not google play store" do
      slack_deployment_run.upload_to_playstore!
      expect(slack_deployment_run.reload.started?).to be true
    end

    it "uploads the package to store and marks the run as uploaded" do
      providable = store_deployment_run.integration.providable
      allow(providable).to receive(:upload).and_return(GitHub::Result.new)

      store_deployment_run.upload_to_playstore!

      expect(providable).to have_received(:upload).once
      expect(store_deployment_run.reload.uploaded?).to be(true)
    end

    it "marks deployment runs as upload failed if upload fails" do
      providable = store_deployment_run.integration.providable
      allow(providable).to receive(:upload).and_return(GitHub::Result.new { raise })

      store_deployment_run.upload_to_playstore!

      expect(store_deployment_run.reload.uploaded?).to be(false)
      expect(store_deployment_run.reload.upload_failed?).to be(true)
    end
  end

  describe "#complete!" do
    let(:step) { create(:releases_step, :with_deployment) }
    let(:step_run) { create(:releases_step_run, :deployment_started, step: step) }

    before do
      create_list(:deployment, 2, step: step)
    end

    it "marks the deployment run as released" do
      deployment_run = create(:deployment_run, :uploaded, deployment: step.deployments[0], step_run: step_run)

      deployment_run.complete!

      expect(deployment_run.reload.released?).to be(true)
    end

    it "marks the step run as success if all deployments for the step are complete" do
      _deployment_run1 = create(:deployment_run, :released, deployment: step.deployments[0], step_run: step_run)
      deployment_run2 = create(:deployment_run, :uploaded, deployment: step.deployments[1], step_run: step_run)
      _deployment_run3 = create(:deployment_run, :released, deployment: step.deployments[2], step_run: step_run)

      deployment_run2.complete!

      expect(deployment_run2.reload.released?).to be(true)
      expect(step_run.reload.success?).to be(true)
    end

    it "does not mark the step run as success if all deployments are not finished" do
      _deployment_run1 = create(:deployment_run, :released, deployment: step.deployments[0], step_run: step_run)
      deployment_run2 = create(:deployment_run, :uploaded, deployment: step.deployments[1], step_run: step_run)

      deployment_run2.complete!

      expect(deployment_run2.reload.released?).to be(true)
      expect(step_run.reload.success?).to be(false)
    end
  end
end
