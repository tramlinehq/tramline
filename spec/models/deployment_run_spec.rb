require "rails_helper"

describe DeploymentRun do
  it "has a valid factory" do
    expect(create(:deployment_run)).to be_valid
  end

  describe "#dispatch!" do
    context "when any platform" do
      let(:step) { create(:releases_step, :with_deployment) }
      let(:step_run) { create(:releases_step_run, :build_available, step: step) }

      it "marks the step run as deployment_started if first deployment regardless of order" do
        deployment1 = step.deployments.first
        deployment2 = create(:deployment, step: step)
        deployment_run2 = create(:deployment_run, :created, deployment: deployment2, step_run: step_run)

        deployment_run2.dispatch!
        _deployment_run1 = create(:deployment_run, :created, deployment: deployment1, step_run: step_run)

        expect(step_run.reload.deployment_started?).to be(true)
      end

      it "does not change the step run if not the first deployment" do
        deployment1 = step.deployments.first
        deployment2 = create(:deployment, step: step)
        _deployment_run1 = create(:deployment_run, :created, deployment: deployment1, step_run: step_run)
        deployment_run2 = create(:deployment_run, :created, deployment: deployment2, step_run: step_run)

        deployment_run2.dispatch!

        expect(step_run.reload.deployment_started?).not_to be(true)
      end
    end

    context "when android" do
      let(:step) { create(:releases_step, :with_deployment) }
      let(:step_run) { create(:releases_step_run, :build_available, step: step) }

      it "marks as completed if deployment is external" do
        external_deployment = create(:deployment, step: step, integration: nil)
        deployment_run = create(:deployment_run, :created, deployment: external_deployment, step_run: step_run)

        deployment_run.dispatch!
        expect(deployment_run.reload.released?).to be(true)
      end

      it "starts upload for play store if deployment has google play store integration" do
        play_upload_job = Deployments::GooglePlayStore::Upload
        deployment = create(:deployment, integration: step.train.build_channel_integrations.first, step: step)
        deployment_run = create(:deployment_run, :created, deployment: deployment, step_run: step_run)
        allow(play_upload_job).to receive(:perform_later)

        deployment_run.dispatch!
        expect(play_upload_job).to have_received(:perform_later).with(deployment_run.id).once
      end

      it "starts deploy for slack if deployment has slack integration" do
        slack_deploy_job = Deployments::Slack
        slack_integration = create(:integration, :with_slack, app: step.app)
        deployment = create(:deployment, integration: slack_integration, step: step)
        deployment_run = create(:deployment_run, :created, deployment: deployment, step_run: step_run)
        allow(slack_deploy_job).to receive(:perform_later)

        deployment_run.dispatch!
        expect(slack_deploy_job).to have_received(:perform_later).with(deployment_run.id).once
      end
    end

    context "when ios" do
      let(:app) { create(:app, :ios) }
      let(:train) { create(:releases_train, app: app) }
      let(:step) { create(:releases_step, :with_deployment, train: train) }
      let(:step_run) { create(:releases_step_run, :build_found_in_store, step: step) }

      it "marks as completed if deployment is external" do
        external_deployment = create(:deployment, step: step, integration: nil)
        deployment_run = create(:deployment_run, :created, deployment: external_deployment, step_run: step_run)

        deployment_run.dispatch!
        expect(deployment_run.reload.released?).to be(true)
      end

      it "starts distribution if deployment has app store integration" do
        job = Deployments::AppStoreConnect::TestFlightReleaseJob
        deployment = create(:deployment, integration: train.build_channel_integrations.first, step: step)
        deployment_run = create(:deployment_run, :created, deployment: deployment, step_run: step_run)
        allow(job).to receive(:perform_later)

        deployment_run.dispatch!
        expect(job).to have_received(:perform_later).with(deployment_run.id).once
      end
    end
  end

  describe "#start_upload!" do
    let(:step) { create(:releases_step, :with_deployment) }
    let(:step_run) { create(:releases_step_run, :deployment_started, step: step) }

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
  end

  describe "#upload_to_playstore!" do
    let(:slack_deployment_run) { create(:deployment_run, :started, :with_slack) }
    let(:store_deployment_run) { create(:deployment_run, :started, :with_google_play_store) }
    let(:providable_dbl) { instance_double(GooglePlayStoreIntegration) }

    before do
      allow_any_instance_of(described_class).to receive(:provider).and_return(providable_dbl)
    end

    it "does nothing if deployment is not google play store" do
      slack_deployment_run.upload_to_playstore!
      expect(slack_deployment_run.reload.started?).to be true
    end

    it "uploads the package to store and marks the run as uploaded" do
      allow(providable_dbl).to receive(:upload).and_return(GitHub::Result.new)
      expect { store_deployment_run.upload_to_playstore! }
        .to change(store_deployment_run, :uploaded?).from(false).to(true)
    end

    it "marks deployment runs as upload failed if upload fails" do
      allow(providable_dbl).to receive(:upload).and_return(GitHub::Result.new { raise })

      expect { store_deployment_run.upload_to_playstore! }
        .to change(store_deployment_run, :upload_failed?).from(false).to(true)
    end

    it "does not mark the run as uploaded twice or raise an exception" do
      allow(providable_dbl).to receive(:upload).and_return(GitHub::Result.new)
      store_deployment_run.upload_to_playstore!
      expect { store_deployment_run.upload_to_playstore! }.not_to change(store_deployment_run, :uploaded?)
    end
  end

  describe "#push_to_slack!" do
    let(:slack_deployment_run) { create(:deployment_run, :started, :with_slack) }
    let(:store_deployment_run) { create(:deployment_run, :started, :with_google_play_store) }
    let(:providable_dbl) { instance_double(SlackIntegration) }

    before do
      allow_any_instance_of(described_class).to receive(:provider).and_return(providable_dbl)
      allow(providable_dbl).to receive(:deploy!)
    end

    it "does nothing if deployment is not slack" do
      store_deployment_run.push_to_slack!
      expect(store_deployment_run.reload.started?).to be true
    end

    it "deploys to slack and marks the run as released" do
      expect { slack_deployment_run.push_to_slack! }.to change(slack_deployment_run, :released?).from(false).to(true)
    end

    it "does not mark the run as released twice or raise an exception" do
      slack_deployment_run.push_to_slack!

      expect { slack_deployment_run.push_to_slack! }.not_to change(slack_deployment_run, :released?)
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
      _incomplete_run = create(:deployment_run, :uploaded, deployment: step.deployments[0], step_run: step_run)
      completable_run = create(:deployment_run, :uploaded, deployment: step.deployments[1], step_run: step_run)

      completable_run.complete!

      expect(completable_run.reload.released?).to be(true)
      expect(step_run.reload.success?).to be(false)
    end
  end

  describe "#start_rollout!" do
    let(:step) { create(:releases_step, :release, :with_deployment) }
    let(:step_run) { create(:releases_step_run, :deployment_started, step: step) }
    let(:providable_dbl) { instance_double(GooglePlayStoreIntegration) }

    before do
      allow_any_instance_of(described_class).to receive(:provider).and_return(providable_dbl)
    end

    it "only starts when staged rollout is enabled for the deployment" do
      allow(providable_dbl).to receive(:create_draft_release).and_return(GitHub::Result.new)
      deployment = create(:deployment, :with_google_play_store, step: step_run.step)
      run = create(:deployment_run, :uploaded, deployment:)

      expect { run.start_rollout! }.to raise_error(AASM::InvalidTransition)
    end

    it "creates a staged rollout association" do
      allow(providable_dbl).to receive(:create_draft_release).and_return(GitHub::Result.new)
      deployment = create(:deployment, :with_google_play_store, :with_staged_rollout, step: step_run.step)
      run = create(:deployment_run, :uploaded, deployment:)

      run.start_rollout!

      expect(run.reload.staged_rollout).to be_present
    end

    it "creates a draft release" do
      allow(providable_dbl).to receive(:create_draft_release).and_return(GitHub::Result.new)
      staged_rollout_config = [1, 100]
      deployment = create(:deployment, :with_google_play_store, :with_staged_rollout, staged_rollout_config:, step: step_run.step)
      run = create(:deployment_run, :uploaded, deployment:)

      run.start_rollout!

      expect(providable_dbl).to have_received(:create_draft_release)
    end

    it "marks it as rollout_started" do
      allow(providable_dbl).to receive(:create_draft_release).and_return(GitHub::Result.new)
      deployment = create(:deployment, :with_google_play_store, :with_staged_rollout, step: step_run.step)
      run = create(:deployment_run, :uploaded, deployment:)

      run.start_rollout!

      expect(run.reload.rollout_started?).to be(true)
    end

    it "marks it as failed if create draft release fails" do
      allow(providable_dbl).to receive(:create_draft_release).and_return(GitHub::Result.new { raise })
      deployment = create(:deployment, :with_google_play_store, :with_staged_rollout, step: step_run.step)
      run = create(:deployment_run, :uploaded, deployment:)

      run.start_rollout!

      expect(run.reload.failed?).to be(true)
    end

    it "fails to create staged rollout if run is not rolloutable" do
      allow(providable_dbl).to receive(:create_draft_release).and_return(GitHub::Result.new)
      deployment = create(:deployment, :with_google_play_store, :with_staged_rollout, step: step_run.step)
      run = create(:deployment_run, :uploaded, deployment:)
      run.release.update(status: "stopped")

      run.start_rollout!

      expect(run.reload.staged_rollout).not_to be_present
    end
  end

  describe "#start_release!" do
    let(:step) { create(:releases_step, :release, :with_deployment) }
    let(:step_run) { create(:releases_step_run, :deployment_started, step: step) }
    let(:providable_dbl) { instance_double(GooglePlayStoreIntegration) }

    before do
      allow_any_instance_of(described_class).to receive(:provider).and_return(providable_dbl)
    end

    it "kicks off the rollout if possible" do
      allow(providable_dbl).to receive(:create_draft_release).and_return(GitHub::Result.new)
      deployment = create(:deployment, :with_google_play_store, :with_staged_rollout, step: step_run.step)
      run = create(:deployment_run, :uploaded, deployment:)

      run.start_release!

      expect(run.reload.rollout_started?).to be(true)
    end

    context "with no rollout" do
      it "fully promotes to the store" do
        full_release_value = 100
        allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
        deployment = create(:deployment, :with_google_play_store, step: step_run.step)
        run = create(:deployment_run, :uploaded, deployment:)

        run.start_release!

        expect(providable_dbl).to have_received(:rollout_release).with(anything, anything, anything, full_release_value)
        expect(run.reload.released?).to be(true)
      end

      it "completes the run" do
        allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
        deployment = create(:deployment, :with_google_play_store, step: step_run.step)
        run = create(:deployment_run, :uploaded, deployment:)

        run.start_release!

        expect(run.reload.released?).to be(true)
      end
    end
  end

  describe "#halt_release_in_playstore!" do
    let(:step) { create(:releases_step, :release, :with_deployment) }
    let(:step_run) { create(:releases_step_run, :deployment_started, step: step) }
    let(:deployment) { create(:deployment, :with_google_play_store, :with_staged_rollout, step: step_run.step) }
    let(:run) { create(:deployment_run, :rollout_started, deployment:, step_run:) }
    let(:providable_dbl) { instance_double(GooglePlayStoreIntegration) }

    before do
      allow_any_instance_of(described_class).to receive(:provider).and_return(providable_dbl)
    end

    it "does nothing if rollout hasn't started" do
      unstarted_run = create(:deployment_run, :uploaded, deployment:, step_run:)
      allow(providable_dbl).to receive(:halt_release).and_return(GitHub::Result.new)

      unstarted_run.halt_release_in_playstore!(rollout_value: 10.0) {}

      expect(providable_dbl).not_to have_received(:halt_release)
    end

    it "halts the release on playstore" do
      allow(providable_dbl).to receive(:halt_release).and_return(GitHub::Result.new)

      run.halt_release_in_playstore!(rollout_value: 10.0) {}

      expect(providable_dbl).to have_received(:halt_release)
    end

    it "raises an exception if no rollout value is passed" do
      expect { run.halt_release_in_playstore!(rollout_value: nil) {} }.to raise_error(ArgumentError)
    end
  end
end
