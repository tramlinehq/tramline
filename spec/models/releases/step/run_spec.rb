require "rails_helper"

describe Releases::Step::Run, type: :model do
  it "has a valid factory" do
    expect(create(:releases_step_run)).to be_valid
  end

  describe "#similar_deployment_runs_for" do
    let(:active_train) { create(:releases_train, :active) }
    let(:steps) { create_list(:releases_step, 2, :with_deployment, train: active_train) }
    let(:step_run) { create(:releases_step_run, step: steps.first) }

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
      second_step_run = create(:releases_step_run, step: second_step)
      integration = create(:integration)
      deployments = create_list(:deployment, 2, step: steps.first, integration: integration)
      second_step_deployment = create(:deployment, step: second_step, integration: integration)
      deployment_run = create(:deployment_run, step_run: step_run, deployment: deployments[0])
      expected_run = create(:deployment_run, :started, step_run: step_run, deployment: deployments[1])
      _ignored_run = create(:deployment_run, :started, step_run: second_step_run, deployment: second_step_deployment)

      expect(step_run.similar_deployment_runs_for(deployment_run)).to contain_exactly(expected_run)
    end
  end

  describe "#previous_deployed_run" do
    let(:active_train) { create(:releases_train, :active) }
    let(:step) { create(:releases_step, :with_deployment, train: active_train) }
    let(:train_run) { create(:releases_train_run, train: active_train) }

    context "when there is a last run that has a deployment" do
      it "returns for deployment_started" do
        step_run1 = create(:releases_step_run, :deployment_started, step: step, train_run: train_run)
        step_run2 = create(:releases_step_run, step: step, train_run: train_run)

        expect(step_run2.previous_deployed_run).to eq step_run1
        expect(step_run1.previous_deployed_run).to be_nil
      end

      it "returns for deployment_failed" do
        step_run1 = create(:releases_step_run, :deployment_failed, step: step, train_run: train_run)
        step_run2 = create(:releases_step_run, step: step, train_run: train_run)

        expect(step_run2.previous_deployed_run).to eq step_run1
        expect(step_run1.previous_deployed_run).to be_nil
      end

      it "returns for success" do
        step_run1 = create(:releases_step_run, :success, step: step, train_run: train_run)
        step_run2 = create(:releases_step_run, step: step, train_run: train_run)

        expect(step_run2.previous_deployed_run).to eq step_run1
        expect(step_run1.previous_deployed_run).to be_nil
      end
    end

    it "returns nothing for other statuses" do
      step_run1 = create(:releases_step_run, :build_ready, step: step, train_run: train_run)
      step_run2 = create(:releases_step_run, step: step, train_run: train_run)

      expect(step_run2.previous_deployed_run).to be_nil
      expect(step_run1.previous_deployed_run).to be_nil
    end
  end

  describe "#previous_runs" do
    let(:active_train) { create(:releases_train, :active) }
    let(:steps) { create_list(:releases_step, 2, :with_deployment, train: active_train) }

    it "returns all previous runs, not later runs" do
      train_run = create(:releases_train_run, train: active_train)
      step1_run1 = create(:releases_step_run, step: steps.first, train_run: train_run)
      step1_run2 = create(:releases_step_run, step: steps.first, train_run: train_run)
      _step1_run3 = create(:releases_step_run, step: steps.first, train_run: train_run)

      expect(step1_run2.previous_runs).to contain_exactly(step1_run1)
    end
  end

  describe "#other_runs" do
    let(:active_train) { create(:releases_train, :active) }
    let(:steps) { create_list(:releases_step, 2, :with_deployment, train: active_train) }

    it "returns all runs except itself" do
      train_run = create(:releases_train_run, train: active_train)
      step1_run1 = create(:releases_step_run, step: steps.first, train_run: train_run)
      step1_run2 = create(:releases_step_run, step: steps.first, train_run: train_run)
      step1_run3 = create(:releases_step_run, step: steps.first, train_run: train_run)

      expect(step1_run2.other_runs).to contain_exactly(step1_run1, step1_run3)
    end
  end

  describe "#manually_startable_deployment?" do
    let(:active_train) { create(:releases_train, :active) }

    it "is false when train is inactive" do
      step = create(:releases_step, :with_deployment, train: create(:releases_train, :inactive))
      deployment = create(:deployment, step: step)
      step_run = create(:releases_step_run, step: step)

      expect(step_run.manually_startable_deployment?(deployment)).to be false
    end

    it "is false when there are no active train runs" do
      step = create(:releases_step, :with_deployment, train: active_train)
      step_run = create(:releases_step_run, step: step)
      deployment = create(:deployment, step: step)
      _inactive_train_run = create(:releases_train_run, train: active_train, status: "finished")

      expect(step_run.manually_startable_deployment?(deployment)).to be false
    end

    it "is false when it is the first deployment" do
      step = create(:releases_step, :with_deployment, train: active_train)
      step_run = create(:releases_step_run, step: step)
      deployment = create(:deployment, step: step)
      _active_train_run = create(:releases_train_run, train: active_train, status: "on_track")

      expect(step_run.manually_startable_deployment?(deployment)).to be false
    end

    it "is false when no other deployment runs have happened" do
      step = create(:releases_step, :with_deployment, train: active_train)
      step_run = create(:releases_step_run, step: step)
      deployment = create(:deployment, step: step)
      _active_train_run = create(:releases_train_run, train: active_train, status: "on_track")
      _deployment_run = create(:deployment_run, step_run: step_run, deployment: deployment, status: "released")

      expect(step_run.manually_startable_deployment?(deployment)).to be false
    end

    it "is true when it is the running step's next-in-line deployment" do
      step = create(:releases_step, :with_deployment, train: active_train)
      _inactive_train_run = create(:releases_train_run, train: active_train, status: "finished")
      inactive_step_run = create(:releases_step_run, step: step, status: "success")
      _active_train_run = create(:releases_train_run, train: active_train, status: "on_track")
      running_step_run = create(:releases_step_run, step: step, status: "on_track")
      deployment1 = create(:deployment, step: step)
      _deployment_run1 = create(:deployment_run, step_run: running_step_run, deployment: deployment1, status: "released")
      deployment2 = create(:deployment, step: step)

      expect(running_step_run.manually_startable_deployment?(deployment1)).to be false
      expect(running_step_run.manually_startable_deployment?(deployment2)).to be true
      expect(inactive_step_run.manually_startable_deployment?(deployment1)).to be false
      expect(inactive_step_run.manually_startable_deployment?(deployment2)).to be false
    end
  end

  describe "#trigger_deploys" do
    before do
      allow(Triggers::Deployment).to receive(:call)
    end

    it "triggers the deployment for the step run" do
      step_run = create(:releases_step_run, :build_available)

      step_run.trigger_deploys

      expect(Triggers::Deployment).to have_received(:call).with(step_run: step_run).once
    end

    context "when auto-triggering multiple deployments" do
      let(:step) { create(:releases_step, :with_deployment) }

      before do
        create_list(:deployment, 2, step: step)
      end

      it "triggers multiple deployments when the step has run previously" do
        old_step_run = create(:releases_step_run, :success, step: step, scheduled_at: 1.minute.ago)

        step.deployments.each do |deployment|
          create(:deployment_run, deployment: deployment, step_run: old_step_run)
        end

        new_step_run = create(:releases_step_run, :build_ready, step: step, train_run: old_step_run.train_run)

        new_step_run.trigger_deploys

        expect(Triggers::Deployment).to have_received(:call).with(step_run: new_step_run.reload, deployment: step.deployments[0]).once
        expect(Triggers::Deployment).to have_received(:call).with(step_run: new_step_run.reload, deployment: step.deployments[1]).once
        expect(Triggers::Deployment).to have_received(:call).with(step_run: new_step_run.reload, deployment: step.deployments[2]).once
      end

      it "triggers only the deployment that have run before" do
        old_step_run = create(:releases_step_run, :deployment_started, step: step, scheduled_at: 1.minute.ago)
        create(:deployment_run, deployment: step.deployments[0], step_run: old_step_run)
        create(:deployment_run, deployment: step.deployments[1], step_run: old_step_run)

        new_step_run = create(:releases_step_run, :build_ready, step: step, train_run: old_step_run.train_run)

        new_step_run.trigger_deploys

        expect(Triggers::Deployment).to have_received(:call).with(step_run: new_step_run.reload, deployment: step.deployments[0]).once
        expect(Triggers::Deployment).to have_received(:call).with(step_run: new_step_run.reload, deployment: step.deployments[1]).once
        expect(Triggers::Deployment).not_to have_received(:call).with(step_run: new_step_run.reload, deployment: step.deployments[2])
      end

      it "triggers all deployments that have run in the last deployed run" do
        older_step_run = create(:releases_step_run, :deployment_started, step: step, scheduled_at: 2.minutes.ago)
        create(:deployment_run, deployment: step.deployments[0], step_run: older_step_run)
        create(:deployment_run, deployment: step.deployments[1], step_run: older_step_run)

        _old_failed_step_run = create(:releases_step_run, :ci_workflow_failed, step: step,
          train_run: older_step_run.train_run, scheduled_at: 1.minute.ago)

        new_step_run = create(:releases_step_run, :build_ready, step: step, train_run: older_step_run.train_run)

        new_step_run.trigger_deploys

        expect(Triggers::Deployment).to have_received(:call).with(step_run: new_step_run.reload, deployment: step.deployments[0]).once
        expect(Triggers::Deployment).to have_received(:call).with(step_run: new_step_run.reload, deployment: step.deployments[1]).once
        expect(Triggers::Deployment).not_to have_received(:call).with(step_run: new_step_run.reload, deployment: step.deployments[2])
      end

      it "triggers all deployments that have run before even if they had failed" do
        older_step_run = create(:releases_step_run, :deployment_failed, step: step, scheduled_at: 2.minutes.ago)
        create(:deployment_run, :released, deployment: step.deployments[0], step_run: older_step_run)
        create(:deployment_run, :failed, deployment: step.deployments[1], step_run: older_step_run)

        new_step_run = create(:releases_step_run, :build_ready, step: step, train_run: older_step_run.train_run)

        new_step_run.trigger_deploys

        expect(Triggers::Deployment).to have_received(:call).with(step_run: new_step_run.reload, deployment: step.deployments[0]).once
        expect(Triggers::Deployment).to have_received(:call).with(step_run: new_step_run.reload, deployment: step.deployments[1]).once
        expect(Triggers::Deployment).not_to have_received(:call).with(step_run: new_step_run.reload, deployment: step.deployments[2])
      end
    end
  end

  describe "#trigger_ci!" do
    let(:ci_ref) { Faker::Lorem.word }
    let(:ci_link) { Faker::Internet.url }

    before do
      allow_any_instance_of(GithubIntegration).to receive(:trigger_workflow_run!).and_return(ci_ref:, ci_link:)
    end

    it "transitions state" do
      step_run = create(:releases_step_run)

      step_run.trigger_ci!

      expect(step_run.ci_workflow_triggered?).to be(true)
    end

    it "updates ci metadata" do
      step_run = create(:releases_step_run)

      step_run.trigger_ci!
      step_run.reload

      expect(step_run.ci_ref).to eq(ci_ref)
      expect(step_run.ci_link).to eq(ci_link)
    end

    it "stamps an event" do
      step_run = create(:releases_step_run)
      id = step_run.id
      name = step_run.class.name
      allow(PassportJob).to receive(:perform_later)

      step_run.trigger_ci!

      expect(PassportJob).to have_received(:perform_later).with(id, name, hash_including(reason: :ci_triggered)).once
    end
  end
end
