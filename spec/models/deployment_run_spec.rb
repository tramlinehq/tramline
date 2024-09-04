require "rails_helper"

describe DeploymentRun do
  it "has a valid factory" do
    expect(create(:deployment_run)).to be_valid
  end

  describe "#dispatch!" do
    context "when any platform" do
      let(:step) { create(:step, :with_deployment) }
      let(:step_run) { create(:step_run, :build_available, step: step) }

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
      let(:step) { create(:step, :with_deployment) }
      let(:step_run) { create(:step_run, :build_available, step: step) }

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
        slack_deploy_job = Deployments::SlackJob
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
      let(:train) { create(:train, app: app) }
      let(:release_platform) { create(:release_platform, train: train, platform: "ios") }
      let(:step) { create(:step, :with_deployment, release_platform:) }
      let(:step_run) { create(:step_run, :build_found_in_store, step: step) }

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

  describe "#dispatch_fail!" do
    it "sets the failure reason during transitioning" do
      run = create(:deployment_run, :uploaded)
      run.dispatch_fail!(reason: :unknown_failure)

      expect(run.reload.failure_reason).to eq("unknown_failure")
    end

    it "does not set the failure reason during transitioning if no reason is passed" do
      run = create(:deployment_run, :uploaded)
      run.dispatch_fail!

      expect(run.reload.failure_reason).to be_nil
    end

    it "fails the step run if there are no more deployments to be run" do
      step_run = create(:step_run, :deployment_started)
      run = create(:deployment_run, :uploaded, step_run:)
      run.dispatch_fail!

      expect(step_run.reload.failed?).to be(true)
    end

    it "does not fail the step run if there are more deployments to be run" do
      step = create(:step, :with_deployment)
      _another_deployment = create(:deployment, step:)
      step_run = create(:step_run, :deployment_started)
      run = create(:deployment_run, :uploaded, step_run:, deployment: step.deployments.first)
      run.dispatch_fail!

      expect(step_run.reload.failed?).to be(false)
    end
  end

  describe "#upload!" do
    let(:step) { create(:step, :with_deployment) }
    let(:step_run) { create(:step_run, :deployment_started, step: step) }

    it "marks self as uploaded" do
      deployment = create(:deployment, step: step)
      deployment_run = create(:deployment_run, :started, deployment: deployment, step_run: step_run)

      deployment_run.upload!

      expect(deployment_run.reload.uploaded?).to be(true)
    end
  end

  describe "#push_to_slack!" do
    let(:app) { create(:app, :android) }
    let(:slack_deployment_run) { create(:deployment_run, :started, :with_slack) }
    let(:store_deployment) { create(:deployment, :with_step, integration: app.android_store_provider.integration) }
    let(:store_deployment_run) { create(:deployment_run, :started, deployment: store_deployment) }
    let(:providable_dbl) { instance_double(SlackIntegration) }

    before do
      allow_any_instance_of(described_class).to receive(:provider).and_return(providable_dbl)
      allow(providable_dbl).to receive(:deploy!)
      allow(providable_dbl).to receive(:deep_link)
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
    let(:step) { create(:step, :with_deployment) }
    let(:step_run) { create(:step_run, :deployment_started, step: step) }

    before do
      create_list(:deployment, 2, step: step)
    end

    it "marks the deployment run as released" do
      deployment_run = create(:deployment_run, :uploaded, deployment: step.deployments[0], step_run: step_run)

      deployment_run.complete!

      expect(deployment_run.reload.released?).to be(true)
    end

    it "marks the step run as success if all deployments for the step are complete" do
      repo_integration = instance_double(Installations::Github::Api)
      allow(Installations::Github::Api).to receive(:new).and_return(repo_integration)
      allow(repo_integration).to receive(:create_tag!)
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

    context "when external release" do
      it "updates timestamps on the external release" do
        deployment_run = create(:deployment_run, :uploaded, :with_external_release, deployment: step.deployments[0], step_run: step_run)

        freeze_time do
          deployment_run.complete!

          expect(deployment_run.external_release.released_at).to eq(Time.current)
          expect(deployment_run.external_release.reviewed_at).to eq(Time.current)
        end
      end

      it "does not update the reviewed_at timestamp if already set" do
        deployment_run = create(:deployment_run, :uploaded, :with_external_release, deployment: step.deployments[0], step_run: step_run)
        deployment_run.external_release.update(reviewed_at: 1.hour.ago)

        freeze_time do
          deployment_run.complete!

          expect(deployment_run.external_release.released_at).to eq(Time.current)
          expect(deployment_run.external_release.reviewed_at).not_to eq(Time.current)
        end
      end
    end
  end

  describe "#start_release!" do
    let(:providable_dbl) { instance_double(GooglePlayStoreIntegration) }

    before do
      allow_any_instance_of(described_class).to receive(:provider).and_return(providable_dbl)
      allow(providable_dbl).to receive(:deep_link).and_return(nil)
    end

    context "with rollout" do
      let(:factory_tree) { create_deployment_tree(:android, :with_staged_rollout, step_traits: [:release]) }
      let(:step) { factory_tree[:step] }
      let(:deployment) { factory_tree[:deployment] }
      let(:store_integration) { factory_tree[:train].build_channel_integrations.first }
      let(:step_run) { create(:step_run, :deployment_started, step:) }

      it "kicks off the rollout if possible" do
        allow(providable_dbl).to receive(:create_draft_release).and_return(GitHub::Result.new)
        run = create(:deployment_run, :uploaded, deployment:)

        run.start_release!

        expect(run.reload.rollout_started?).to be(true)
      end

      it "creates a staged rollout association" do
        allow(providable_dbl).to receive(:create_draft_release).and_return(GitHub::Result.new)
        run = create(:deployment_run, :uploaded, deployment:)

        run.start_release!

        expect(run.reload.staged_rollout).to be_present
      end

      it "creates a draft deployments" do
        allow(providable_dbl).to receive(:create_draft_release).and_return(GitHub::Result.new)
        run = create(:deployment_run, :uploaded, deployment:)

        run.start_release!

        expect(providable_dbl).to have_received(:create_draft_release)
      end

      it "marks it as failed if create draft deployments fails" do
        allow(providable_dbl).to receive(:create_draft_release).and_return(GitHub::Result.new { raise })
        run = create(:deployment_run, :uploaded, deployment:)

        run.start_release!

        expect(run.reload.failed?).to be(true)
      end

      it "fails to create staged rollout if run is not rolloutable" do
        allow(providable_dbl).to receive(:create_draft_release).and_return(GitHub::Result.new)
        run = create(:deployment_run, :uploaded, deployment:)
        run.release_platform_run.update(status: "stopped")

        run.start_release!

        expect(run.reload.staged_rollout).not_to be_present
      end
    end

    context "with no rollout" do
      let(:factory_tree) { create_deployment_tree(:android, step_traits: [:release]) }
      let(:step) { factory_tree[:step] }
      let(:deployment) { factory_tree[:deployment] }
      let(:store_integration) { factory_tree[:train].build_channel_integrations.first }
      let(:step_run) { create(:step_run, :deployment_started, step:) }

      before do
        repo_integration = instance_double(Installations::Github::Api)
        allow(Installations::Github::Api).to receive(:new).and_return(repo_integration)
        allow(repo_integration).to receive(:create_tag!)
        allow(providable_dbl).to receive(:deep_link)
      end

      it "fully promotes to the store" do
        full_release_value = 100
        allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
        run = create(:deployment_run, :uploaded, deployment:)

        run.start_release!

        expect(providable_dbl).to(
          have_received(:rollout_release)
            .with(
              anything,
              anything,
              anything,
              full_release_value,
              anything
            )
        )
        expect(run.reload.released?).to be(true)
      end

      it "completes the run" do
        allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
        run = create(:deployment_run, :uploaded, deployment:)

        run.start_release!

        expect(run.reload.released?).to be(true)
      end
    end
  end

  describe "#healthy?" do
    let(:deployment_run) { create(:deployment_run, :rollout_started) }

    it "returns true if there are no rules defined" do
      expect(deployment_run.healthy?).to be(true)
    end

    context "when rules are defined" do
      let(:user_stability_rule) {
        create(:release_health_rule,
          :user_stability,
          release_platform: deployment_run.release_platform)
      }
      let(:session_stability_rule) {
        create(:release_health_rule,
          :session_stability,
          release_platform: deployment_run.release_platform)
      }

      it "returns false if a rule is unhealthy" do
        create(:release_health_event, :unhealthy, release_health_rule: user_stability_rule, deployment_run:)
        expect(deployment_run.healthy?).to be(false)
      end

      it "returns true if there are all rules are healthy" do
        create(:release_health_event, :healthy, release_health_rule: user_stability_rule, deployment_run:)
        create(:release_health_event, :healthy, release_health_rule: session_stability_rule, deployment_run:)
        expect(deployment_run.healthy?).to be(true)
      end

      it "returns true if there are all no events" do
        expect(deployment_run.healthy?).to be(true)
      end
    end
  end
end
