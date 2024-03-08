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
    let(:train) { create(:train, version_seeded_with: "1.1.0") }
    let(:release_platform) { create(:release_platform, train:) }

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

    it "is false when the step run is cancelled" do
      step = create(:step, :with_deployment, release_platform: release_platform)
      step_run = create(:step_run, :cancelled, step: step)
      deployment = create(:deployment, step: step)

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
      let(:train) { create(:train) }
      let(:store_integration) { train.build_channel_integrations.first }
      let(:release_platform) { create(:release_platform, train:) }
      let(:release_step) { create(:step, :release, :with_deployment, release_platform:) }
      let(:regular_deployment) { create(:deployment, step: release_step, integration: store_integration) }
      let(:production_deployment) { create(:deployment, :with_staged_rollout, step: release_step, integration: store_integration) }
      let(:release) { create(:release, train:) }
      let(:release_platform_run) { create(:release_platform_run, :on_track, release_platform:, release:) }

      it "is true when it is the running step's next-in-line deployment" do
        inactive_train_run = create(:release_platform_run, release_platform: release_platform, status: "finished")
        inactive_step_run = create(:step_run, step: release_step, release_platform_run: inactive_train_run, status: "success")
        running_step_run = create(:step_run, step: release_step, release_platform_run:, status: "on_track")
        _deployment_run1 = create(:deployment_run, step_run: running_step_run, deployment: regular_deployment, status: "released")

        expect(running_step_run.manually_startable_deployment?(regular_deployment)).to be false
        expect(running_step_run.manually_startable_deployment?(production_deployment)).to be true
        expect(inactive_step_run.manually_startable_deployment?(regular_deployment)).to be false
        expect(inactive_step_run.manually_startable_deployment?(production_deployment)).to be false
      end

      it "is false when it is the running step's next-in-line deployment but previous deployment hasn't finished" do
        running_step_run = create(:step_run, :deployment_started, step: release_step, release_platform_run:)
        _deployment_run1 = create(:deployment_run, step_run: running_step_run, deployment: regular_deployment, status: "uploading")

        expect(running_step_run.manually_startable_deployment?(regular_deployment)).to be false
        expect(running_step_run.manually_startable_deployment?(production_deployment)).to be false
      end

      it "is true when it is the running step's next-in-line deployment, previous deployment hasn't finished and release is in fix mode" do
        inactive_step_run = create(:step_run, :deployment_started, step: release_step, release_platform_run:, build_version: release_platform_run.release_version)
        _old_beta_deployment_run = create(:deployment_run, :released, step_run: inactive_step_run, deployment: regular_deployment)
        _old_prod_deployment_run = create(:deployment_run, :rollout_started, step_run: inactive_step_run, deployment: production_deployment)
        release_platform_run.bump_version!
        running_step_run = create(:step_run, :deployment_started, step: release_step, release_platform_run:)
        _new_beta_deployment_run = create(:deployment_run, :uploaded, step_run: running_step_run, deployment: regular_deployment)

        expect(running_step_run.reload.manually_startable_deployment?(regular_deployment)).to be false
        expect(running_step_run.reload.manually_startable_deployment?(production_deployment)).to be true
      end

      it "is true when it is the running step's next-in-line deployment, previous deployment hasn't finished and release is a hotfix" do
        _older_release = create(:release, :finished, train:, release_type: Release.release_types[:release])
        release = create(:release, train:, release_type: Release.release_types[:hotfix])
        release_platform_run = create(:release_platform_run, :on_track, release_platform:, release:)
        running_step_run = create(:step_run, :deployment_started, step: release_step, release_platform_run:)
        _deployment_run1 = create(:deployment_run, step_run: running_step_run, deployment: regular_deployment, status: "uploading")

        expect(running_step_run.manually_startable_deployment?(regular_deployment)).to be false
        expect(running_step_run.manually_startable_deployment?(production_deployment)).to be true
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

    it "marks the step as finished if the last deployment is a success" do
      repo_integration = instance_double(Installations::Github::Api)
      allow(Installations::Github::Api).to receive(:new).and_return(repo_integration)
      allow(repo_integration).to receive(:create_tag!)
      step = create(:step, :review, :with_deployment)
      step_run = create(:step_run, :deployment_started, step: step)
      first_deployment = step_run.step.deployments.first
      second_deployment = create(:deployment, step:)
      create(:deployment_run, :failed, deployment: first_deployment, step_run: step_run)
      create(:deployment_run, :released, deployment: second_deployment, step_run: step_run)

      step_run.finish_deployment!(second_deployment)

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
      prod_deployment = create(:deployment, :with_production_channel, step: step, integration: step.train.build_channel_integrations.first)
      step_run = create(:step_run, :build_available, step: step)

      step_run.finish_deployment!(regular_deployment)

      expect(Triggers::Deployment).not_to have_received(:call).with(step_run: step_run, deployment: prod_deployment)
    end

    it "does not trigger the next deployment if step is not auto deploy" do
      allow(Triggers::Deployment).to receive(:call)
      step = create(:step, :release, :with_deployment, auto_deploy: false)
      regular_deployment = step.deployments.first
      another_regular_deployment = create(:deployment, step: step)
      step_run = create(:step_run, :build_available, step: step)

      step_run.finish_deployment!(regular_deployment)

      expect(Triggers::Deployment).not_to have_received(:call).with(step_run: step_run, deployment: another_regular_deployment)
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
      platform_release.update!(last_commit: commit_1)
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

  describe "#trigger_ci_worfklow_run!!" do
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
      step_run.trigger_ci_worfklow_run!

      expect(step_run.ci_workflow_triggered?).to be(true)
    end

    it "updates ci metadata" do
      step_run.trigger_ci_worfklow_run!
      step_run.reload

      expect(step_run.ci_ref).to eq(ci_ref)
      expect(step_run.ci_link).to eq(ci_link)
    end

    it "stamps an event" do
      id = step_run.id
      name = step_run.class.name
      allow(PassportJob).to receive(:perform_later)

      step_run.trigger_ci_worfklow_run!

      expect(PassportJob).to have_received(:perform_later).with(id, name, hash_including(reason: :ci_triggered)).once
    end

    it "triggers find workflow run" do
      step_run = create(:step_run)
      id = step_run.id
      allow(Releases::FindWorkflowRun).to receive(:perform_async)

      step_run.trigger_ci_worfklow_run!

      expect(Releases::FindWorkflowRun).to have_received(:perform_async).with(id).once
    end

    it "updates build number" do
      step_run = create(:step_run, build_number: nil)
      allow(Releases::FindWorkflowRun).to receive(:perform_async)

      expect(step_run.build_number).to be_nil
      step_run.trigger_ci_worfklow_run!
      expect(step_run.build_number).not_to be_empty
    end

    (StepRun::STATES.keys - StepRun::END_STATES).each do |trait|
      it "cancels previous running step run when #{trait}" do
        allow(Releases::CancelStepRun).to receive(:perform_later)
        previous_step_run = create(:step_run, trait, step: step_run.step,
          release_platform_run: step_run.release_platform_run,
          scheduled_at: 10.minutes.before(step_run.scheduled_at))

        step_run.trigger_ci_worfklow_run!

        expect(Releases::CancelStepRun).to have_received(:perform_later).with(previous_step_run.id).once
      end

      it "does not cancel later running step run when #{trait}" do
        allow(Releases::CancelStepRun).to receive(:perform_later)
        previous_step_run = create(:step_run, trait, step: step_run.step,
          release_platform_run: step_run.release_platform_run,
          scheduled_at: 10.minutes.after(step_run.scheduled_at))

        step_run.trigger_ci_worfklow_run!

        expect(Releases::CancelStepRun).not_to have_received(:perform_later).with(previous_step_run.id)
      end
    end

    StepRun::END_STATES.each do |trait|
      it "does not cancel previous step run when #{trait}" do
        allow(Releases::CancelStepRun).to receive(:perform_later)
        previous_step_run = create(:step_run, trait, step: step_run.step,
          release_platform_run: step_run.release_platform_run,
          scheduled_at: 10.minutes.before(step_run.scheduled_at))

        step_run.trigger_ci_worfklow_run!

        expect(Releases::CancelStepRun).not_to have_received(:perform_later).with(previous_step_run.id)
      end
    end
  end

  describe "#retry_ci!" do
    let(:step_run) { create(:step_run, :ci_workflow_failed, build_number: "1") }
    let(:providable) { instance_double(GithubIntegration) }

    before do
      allow(step_run).to receive(:ci_cd_provider).and_return(providable)
    end

    context "when retriable" do
      it "retries the same workflow run" do
        allow(WorkflowProcessors::WorkflowRunJob).to receive(:perform_later)
        allow(providable).to receive(:workflow_retriable?).and_return(true)
        allow(providable).to receive(:retry_workflow_run!)

        step_run.retry_ci!

        expect(providable).to have_received(:retry_workflow_run!)
      end

      it "does not update the build number" do
        allow(WorkflowProcessors::WorkflowRunJob).to receive(:perform_later)
        allow(providable).to receive(:workflow_retriable?).and_return(true)
        allow(providable).to receive(:retry_workflow_run!)

        expect(step_run.build_number).to eq("1")
        step_run.retry_ci!
        expect(step_run.build_number).to eq("1")
      end
    end

    context "when non-retriable" do
      it "triggers a new workflow run" do
        allow(WorkflowProcessors::WorkflowRunJob).to receive(:perform_later)
        allow(providable).to receive(:workflow_retriable?).and_return(false)
        allow(providable).to receive(:trigger_workflow_run!)

        step_run.retry_ci!

        expect(providable).to have_received(:trigger_workflow_run!)
      end

      it "does not update the build number" do
        allow(WorkflowProcessors::WorkflowRunJob).to receive(:perform_later)
        allow(providable).to receive(:workflow_retriable?).and_return(false)
        allow(providable).to receive(:trigger_workflow_run!)

        expect(step_run.build_number).to eq("1")
        step_run.retry_ci!
        expect(step_run.build_number).to eq("1")
      end
    end
  end

  describe "#relevant_changes" do
    let(:release_platform) { create(:release_platform) }
    let(:first_step) { create(:step, :with_deployment, release_platform: release_platform) }
    let(:second_step) { create(:step, :with_deployment, release_platform: release_platform) }
    let(:release_platform_run) { create(:release_platform_run, release_platform:) }
    let(:release) { release_platform_run.release }

    it "only shows the messages since the previous success" do
      create(:step_run, :success, step: first_step, release_platform_run:, commit: create(:commit, message: "feat: 1", release:))
      create(:step_run, :build_available, step: first_step, release_platform_run:, commit: create(:commit, message: "feat: 2", release:))
      create(:step_run, :build_not_found_in_store, step: first_step, release_platform_run:, commit: create(:commit, message: "feat: 3", release:))
      latest = create(:step_run, :on_track, step: first_step, release_platform_run:, commit: create(:commit, message: "feat: 4", release:))

      expected = [
        "feat: 2",
        "feat: 3",
        "feat: 4"
      ]

      expect(latest.relevant_changes).to contain_exactly(*expected)
    end

    it "only shows the current message if the previous success was the last one" do
      create(:step_run, :success, step: first_step, release_platform_run:, commit: create(:commit, message: "feat: 1", release:))
      latest = create(:step_run, :on_track, step: first_step, release_platform_run:, commit: create(:commit, message: "feat: 2", release:))

      expect(latest.relevant_changes).to contain_exactly("feat: 2")
    end

    it "shows the changes since last release if it is the only run" do
      release.create_release_changelog(
        commits: [{message: "message 1"}, {message: "message 2"}],
        from_ref: "v1.10.0"
      )
      latest = create(:step_run, :on_track, step: first_step, release_platform_run:, commit: create(:commit, message: "feat: 1", release:))

      expected = [
        "message 1",
        "message 2"
      ]

      expect(latest.relevant_changes).to contain_exactly(*expected)
    end

    it "shows all the messages of the release if a step is run for the first time after several commits" do
      create(:step_run, :success, step: first_step, release_platform_run:, commit: create(:commit, message: "feat: 1", release:))
      create(:step_run, :build_available, step: first_step, release_platform_run:, commit: create(:commit, message: "feat: 2", release:))
      create(:step_run, :build_not_found_in_store, step: first_step, release_platform_run:, commit: create(:commit, message: "feat: 3", release:))
      second_step_run = create(:step_run, :on_track, step: second_step, release_platform_run:, commit: create(:commit, message: "feat: 4", release:))

      expected = [
        "feat: 1",
        "feat: 2",
        "feat: 3",
        "feat: 4"
      ]

      expect(second_step_run.relevant_changes).to contain_exactly(*expected)
    end
  end

  describe "#cancel!" do
    let(:step) { create(:step, :with_deployment) }

    StepRun::WORKFLOW_IMMUTABLE.each do |trait|
      it "cancels the step run in #{trait} state" do
        step_run = create(:step_run, trait, step: step)
        step_run.cancel!

        expect(step_run.reload.cancelled?).to be(true)
      end
    end

    it "cancels the CI workflow if step run is in ci workflow started state" do
      allow(Releases::CancelWorkflowRunJob).to receive(:perform_later)
      step_run = create(:step_run, :ci_workflow_started, step: step)
      step_run.cancel!

      expect(Releases::CancelWorkflowRunJob).to have_received(:perform_later).with(step_run.id).once
      expect(step_run.reload.cancelling?).to be(true)
    end

    it "attempts to cancels the CI workflow if step run is in ci workflow triggered state" do
      allow(Releases::CancelWorkflowRunJob).to receive(:perform_later)
      step_run = create(:step_run, :ci_workflow_triggered, step: step)
      step_run.cancel!

      expect(Releases::CancelWorkflowRunJob).to have_received(:perform_later).with(step_run.id).once
      expect(step_run.reload.cancelling?).to be(true)
    end
  end
end
