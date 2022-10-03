require "rails_helper"

RSpec.describe Releases::Step::Run, type: :model do
  it "has valid spec" do
    expect(create(:releases_step_run)).to be_valid
  end

  describe "#previous_run" do
    let(:active_train) { create(:releases_train, :active) }
    let(:steps) { create_list(:releases_step, 2, train: active_train) }

    it "returns the previous run for its step and train run" do
      train_run = create(:releases_train_run, train: active_train)
      step1_run1 = create(:releases_step_run, step: steps.first, train_run: train_run)
      step1_run2 = create(:releases_step_run, step: steps.first, train_run: train_run)
      step2_run1 = create(:releases_step_run, step: steps.second, train_run: train_run)
      step2_run2 = create(:releases_step_run, step: steps.second, train_run: train_run)

      expect(step1_run2.previous_run).to eq step1_run1
      expect(step2_run2.previous_run).to eq step2_run1
      expect(step1_run1.previous_run).to be_nil
      expect(step2_run1.previous_run).to be_nil
    end
  end

  describe "#previous_runs" do
    let(:active_train) { create(:releases_train, :active) }
    let(:steps) { create_list(:releases_step, 2, train: active_train) }

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
    let(:steps) { create_list(:releases_step, 2, train: active_train) }

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
      step = create(:releases_step, train: create(:releases_train, :inactive))
      deployment = create(:deployment, step: step)
      step_run = create(:releases_step_run, step: step)

      expect(step_run.manually_startable_deployment?(deployment)).to eq false
    end

    it "is false when there are no active train runs" do
      step = create(:releases_step, train: active_train)
      step_run = create(:releases_step_run, step: step)
      deployment = create(:deployment, step: step)
      _inactive_train_run = create(:releases_train_run, train: active_train, status: "finished")

      expect(step_run.manually_startable_deployment?(deployment)).to eq false
    end

    it "is false when it is the first deployment" do
      step = create(:releases_step, train: active_train)
      step_run = create(:releases_step_run, step: step)
      deployment = create(:deployment, step: step)
      _active_train_run = create(:releases_train_run, train: active_train, status: "on_track")

      expect(step_run.manually_startable_deployment?(deployment)).to eq false
    end

    it "is false when no other deployment runs have happened" do
      step = create(:releases_step, train: active_train)
      step_run = create(:releases_step_run, step: step)
      deployment = create(:deployment, step: step)
      _active_train_run = create(:releases_train_run, train: active_train, status: "on_track")
      _deployment_run = create(:deployment_run, step_run: step_run, deployment: deployment, status: "released")

      expect(step_run.manually_startable_deployment?(deployment)).to eq false
    end

    it "is true when it is the running step's next-in-line deployment" do
      step = create(:releases_step, train: active_train)
      _inactive_train_run = create(:releases_train_run, train: active_train, status: "finished")
      inactive_step_run = create(:releases_step_run, step: step, status: "success")
      _active_train_run = create(:releases_train_run, train: active_train, status: "on_track")
      running_step_run = create(:releases_step_run, step: step, status: "on_track")
      deployment1 = create(:deployment, step: step)
      _deployment_run1 = create(:deployment_run, step_run: running_step_run, deployment: deployment1, status: "released")
      deployment2 = create(:deployment, step: step)

      expect(running_step_run.manually_startable_deployment?(deployment1)).to eq false
      expect(running_step_run.manually_startable_deployment?(deployment2)).to eq true
      expect(inactive_step_run.manually_startable_deployment?(deployment1)).to eq false
      expect(inactive_step_run.manually_startable_deployment?(deployment2)).to eq false
    end
  end
end
