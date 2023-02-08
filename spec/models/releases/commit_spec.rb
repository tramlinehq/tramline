require "rails_helper"

describe Releases::Commit do
  it "has valid factory" do
    expect(create(:releases_commit)).to be_valid
  end

  describe "#trigger_step_runs" do
    let(:active_train) { create(:releases_train, :active) }

    it "does it for the first step run if first commit" do
      train_run = create(:releases_train_run, train: active_train)
      step = create(:releases_step, :with_deployment, train: active_train)

      allow(Triggers::StepRun).to receive(:call)

      commit = create(:releases_commit, train: active_train, train_run: train_run)

      expect(Triggers::StepRun).to have_received(:call).with(step, commit, true).once
    end

    it "does it for all steps until the currently running one" do
      train_run = create(:releases_train_run, train: active_train)
      steps = create_list(:releases_step, 2, :with_deployment, train: active_train)
      create(:releases_step_run, :success, step: steps.first, train_run: train_run)
      create(:releases_step_run, step: steps.second, train_run: train_run)

      allow(Triggers::StepRun).to receive(:call)

      commit = create(:releases_commit, train: active_train, train_run: train_run)

      expect(Triggers::StepRun).to have_received(:call).with(steps.first, commit, false).once
      expect(Triggers::StepRun).to have_received(:call).with(steps.second, commit, true).once
    end
  end
end
