require "rails_helper"

describe StepRun do
  it "has a valid factory" do
    expect(create(:step_run)).to be_valid
  end

  describe "#similar_deployment_runs_for" do
    let(:steps) { create_list(:step, 2, :with_deployment) }
    let(:step_run) { create(:step_run, step: steps.first) }

    it "ignores itself" do
      integration = create(:integration)
      deployments = create_list(:deployment, 3, step: steps.first, integration: integration)
      deployment_run = create(:deployment_run, step_run: step_run, deployment: deployments[0])
      expected_run1 = create(:deployment_run, :started, step_run: step_run, deployment: deployments[1])
      expected_run2 = create(:deployment_run, :started, step_run: step_run, deployment: deployments[2])

      expect(step_run.similar_deployment_runs_for(deployment_run)).to contain_exactly(expected_run1, expected_run2)
    end

    it "only picks deployment runs with the same integration" do
      integration = create(:integration)
      different_integration = create(:integration)
      deployment1 = create(:deployment, step: steps.first, integration: integration)
      deployment2 = create(:deployment, step: steps.first, integration: different_integration)
      deployment3 = create(:deployment, step: steps.first, integration: integration)
      deployment_run = create(:deployment_run, step_run: step_run, deployment: deployment1)
      _ignored_run = create(:deployment_run, :started, step_run: step_run, deployment: deployment2)
      expected_run = create(:deployment_run, :started, step_run: step_run, deployment: deployment3)

      expect(step_run.similar_deployment_runs_for(deployment_run)).to contain_exactly(expected_run)
    end

    it "only picks deployment runs which have begun" do
      integration = create(:integration)
      deployments = create_list(:deployment, 3, step: steps.first, integration: integration)
      deployment_run = create(:deployment_run, step_run: step_run, deployment: deployments[0])
      _ignored_run = create(:deployment_run, step_run: step_run, deployment: deployments[1])
      expected_run = create(:deployment_run, :started, step_run: step_run, deployment: deployments[2])

      expect(step_run.similar_deployment_runs_for(deployment_run)).to contain_exactly(expected_run)
    end

    it "only picks deployment runs from the correct step run" do
      second_step = steps.last
      second_step_run = create(:step_run, step: second_step)
      integration = create(:integration)
      deployments = create_list(:deployment, 2, step: steps.first, integration: integration)
      second_step_deployment = create(:deployment, step: second_step, integration: integration)
      deployment_run = create(:deployment_run, step_run: step_run, deployment: deployments[0])
      expected_run = create(:deployment_run, :started, step_run: step_run, deployment: deployments[1])
      _ignored_run = create(:deployment_run, :started, step_run: second_step_run, deployment: second_step_deployment)

      expect(step_run.similar_deployment_runs_for(deployment_run)).to contain_exactly(expected_run)
    end
  end

  describe "#manually_startable_deployment?" do
    let(:release_platform) { create(:release_platform) }

    it "is false when train is inactive" do
      step = create(:step, :with_deployment, release_platform: release_platform)
      deployment = create(:deployment, step: step)
      release_platform.train.update(status: Train.statuses[:inactive])
      step_run = create(:step_run, step: step)

      expect(step_run.manually_startable_deployment?(deployment)).to be false
    end

    it "is false when there are no active train runs" do
      step = create(:step, :with_deployment, release_platform: release_platform)
      step_run = create(:step_run, step: step)
      deployment = create(:deployment, step: step)
      _inactive_train_run = create(:release_platform_run, release_platform: release_platform, status: "finished")

      expect(step_run.manually_startable_deployment?(deployment)).to be false
    end

    it "is false when it is the first deployment" do
      step = create(:step, :with_deployment, release_platform: release_platform)
      step_run = create(:step_run, step: step)
      deployment = create(:deployment, step: step)
      _active_train_run = create(:release_platform_run, release_platform: release_platform, status: "on_track")

      expect(step_run.manually_startable_deployment?(deployment)).to be false
    end

    it "is false when the deployment run has already happened" do
      step = create(:step, :with_deployment, release_platform: release_platform)
      step_run = create(:step_run, step: step)
      deployment = create(:deployment, step: step)
      _active_train_run = create(:release_platform_run, release_platform: release_platform, status: "on_track")
      _deployment_run = create(:deployment_run, step_run: step_run, deployment: deployment, status: "released")

      expect(step_run.manually_startable_deployment?(deployment)).to be false
    end

    context "with release step" do
      it "is true when it is the running step's next-in-line deployment" do
        step = create(:step, :release, :with_deployment, release_platform: release_platform)
        _inactive_train_run = create(:release_platform_run, release_platform: release_platform, status: "finished")
        inactive_step_run = create(:step_run, step: step, status: "success")
        _active_train_run = create(:release_platform_run, release_platform: release_platform, status: "on_track")
        running_step_run = create(:step_run, step: step, status: "on_track")
        deployment1 = create(:deployment, step: step)
        _deployment_run1 = create(:deployment_run, step_run: running_step_run, deployment: deployment1, status: "released")
        deployment2 = create(:deployment, step: step)

        expect(running_step_run.manually_startable_deployment?(deployment1)).to be false
        expect(running_step_run.manually_startable_deployment?(deployment2)).to be true
        expect(inactive_step_run.manually_startable_deployment?(deployment1)).to be false
        expect(inactive_step_run.manually_startable_deployment?(deployment2)).to be false
      end
    end

    context "with review step" do
      it "is false when it is the running step's next-in-line deployment" do
        step = create(:step, :review, :with_deployment, release_platform: release_platform)
        _inactive_train_run = create(:release_platform_run, release_platform: release_platform, status: "finished")
        inactive_step_run = create(:step_run, step: step, status: "success")
        _active_train_run = create(:release_platform_run, release_platform: release_platform, status: "on_track")
        running_step_run = create(:step_run, step: step, status: "on_track")
        deployment1 = create(:deployment, step: step)
        _deployment_run1 = create(:deployment_run, step_run: running_step_run, deployment: deployment1, status: "released")
        deployment2 = create(:deployment, step: step)

        expect(running_step_run.manually_startable_deployment?(deployment1)).to be false
        expect(running_step_run.manually_startable_deployment?(deployment2)).to be false
        expect(inactive_step_run.manually_startable_deployment?(deployment1)).to be false
        expect(inactive_step_run.manually_startable_deployment?(deployment2)).to be false
      end
    end
  end

  describe "#finish_deployment!" do
    it "marks the step as finished if all deployments are finished" do
      repo_integration = instance_double(Installations::Github::Api)
      allow(Installations::Github::Api).to receive(:new).and_return(repo_integration)
      allow(repo_integration).to receive(:create_tag!)
      step = create(:step, :review, :with_deployment)
      step_run = create(:step_run, :deployment_started, step: step)
      first_deployment = step_run.step.deployments.first
      create(:deployment_run, :released, deployment: first_deployment, step_run: step_run)

      step_run.finish_deployment!(first_deployment)

      expect(step_run.reload.success?).to be(true)
    end

    it "triggers the next deployment if there are any" do
      allow(Triggers::Deployment).to receive(:call)
      step = create(:step, :review, :with_deployment)
      second_deployment = create(:deployment, step: step)
      step_run = create(:step_run, :build_available, step: step)
      first_deployment = step_run.step.deployments.first

      step_run.finish_deployment!(first_deployment)

      expect(Triggers::Deployment).to have_received(:call).with(step_run: step_run, deployment: second_deployment).once
    end

    it "does not trigger the next deployment if it is a production channel" do
      allow(Triggers::Deployment).to receive(:call)
      step = create(:step, :release, :with_deployment)
      regular_deployment = step.deployments.first
      prod_deployment = create(:deployment, :with_production_channel, :with_google_play_store, step: step)
      step_run = create(:step_run, :build_available, step: step)

      step_run.finish_deployment!(regular_deployment)

      expect(Triggers::Deployment).not_to have_received(:call).with(step_run: step_run, deployment: prod_deployment)
    end

    it "automatically finishes the release if the release step has completed" do
      repo_integration = instance_double(Installations::Github::Api)
      allow(Installations::Github::Api).to receive(:new).and_return(repo_integration)
      allow(repo_integration).to receive(:create_tag!)
      train = create(:train)
      release = create(:release, train:)
      release_platform = create(:release_platform, train:)
      platform_release = create(:release_platform_run, release_platform:, release:)
      commit_1 = create(:commit, release:)
      step = create(:step, :release, :with_deployment, release_platform:)
      step_run = create(:step_run, :deployment_started, step:, release_platform_run: platform_release, commit: commit_1)
      first_deployment = step_run.step.deployments.first
      create(:deployment_run, :released, deployment: first_deployment, step_run: step_run)

      step_run.finish_deployment!(first_deployment)

      expect(step_run.reload.success?).to be(true)
      expect(step_run.release_platform_run.finished?).to be(true)
    end
  end

  describe "#trigger_deployment" do
    before do
      allow(Triggers::Deployment).to receive(:call)
    end

    it "triggers the deployment for the step run" do
      step_run = create(:step_run, :build_available)
      first_deployment = step_run.step.deployments.first

      step_run.trigger_deployment

      expect(Triggers::Deployment).to have_received(:call).with(step_run: step_run, deployment: first_deployment).once
    end
  end

  describe "#trigger_ci!" do
    let(:ci_ref) { Faker::Lorem.word }
    let(:ci_link) { Faker::Internet.url }
    let(:api_double) { instance_double(Installations::Google::PlayDeveloper::Api) }
    let(:step_run) { create(:step_run) }

    before do
      allow_any_instance_of(GithubIntegration).to receive(:trigger_workflow_run!).and_return(ci_ref:, ci_link:)
      allow_any_instance_of(GooglePlayStoreIntegration).to receive(:installation).and_return(api_double)
      allow(api_double).to receive(:find_latest_build_number).and_return(123)
    end

    it "transitions state" do
      step_run.trigger_ci!

      expect(step_run.ci_workflow_triggered?).to be(true)
    end

    it "updates ci metadata" do
      step_run.trigger_ci!
      step_run.reload

      expect(step_run.ci_ref).to eq(ci_ref)
      expect(step_run.ci_link).to eq(ci_link)
    end

    it "stamps an event" do
      id = step_run.id
      name = step_run.class.name
      allow(PassportJob).to receive(:perform_later)

      step_run.trigger_ci!

      expect(PassportJob).to have_received(:perform_later).with(id, name, hash_including(reason: :ci_triggered)).once
    end

    it "triggers find workflow run" do
      step_run = create(:step_run)
      id = step_run.id
      allow(Releases::FindWorkflowRun).to receive(:perform_async)

      step_run.trigger_ci!

      expect(Releases::FindWorkflowRun).to have_received(:perform_async).with(id).once
    end
  end
end
