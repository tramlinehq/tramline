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
    let(:steps) { create_list(:releases_step, 2, :with_deployment, train: active_train) }

    it "returns the last run that ran a deployment for its step and train run" do
      train_run = create(:releases_train_run, train: active_train)
      step1_run1 = create(:releases_step_run, :deployment_started, step: steps.first, train_run: train_run)
      step1_run2 = create(:releases_step_run, step: steps.first, train_run: train_run)
      step2_run1 = create(:releases_step_run, :success, step: steps.second, train_run: train_run)
      step2_run2 = create(:releases_step_run, step: steps.second, train_run: train_run)

      expect(step1_run2.previous_deployed_run).to eq step1_run1
      expect(step2_run2.previous_deployed_run).to eq step2_run1
      expect(step1_run1.previous_deployed_run).to be_nil
      expect(step2_run1.previous_deployed_run).to be_nil
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
end
