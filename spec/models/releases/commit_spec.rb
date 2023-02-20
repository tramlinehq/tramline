require "rails_helper"

describe Releases::Commit do
  it "has valid factory" do
    expect(create(:releases_commit)).to be_valid
  end

  describe "#trigger_step_runs" do
    let(:train) { create(:releases_train) }

    it "does it for the first step run if first commit" do
      step = create(:releases_step, :with_deployment, train: train)
      train.update(status: Releases::Train.statuses[:active])
      train_run = create(:releases_train_run, train: train)

      allow(Triggers::StepRun).to receive(:call)

      commit = create(:releases_commit, train: train, train_run: train_run)

      expect(Triggers::StepRun).to have_received(:call).with(step, commit).once
    end

    it "does it for all steps until the currently running one" do
      steps = create_list(:releases_step, 2, :with_deployment, train: train)
      train.update(status: Releases::Train.statuses[:active])
      train_run = create(:releases_train_run, train: train)
      create(:releases_step_run, :success, step: steps.first, train_run: train_run)
      create(:releases_step_run, step: steps.second, train_run: train_run)

      allow(Triggers::StepRun).to receive(:call)

      commit = create(:releases_commit, train: train, train_run: train_run)

      expect(Triggers::StepRun).to have_received(:call).with(steps.first, commit).once
      expect(Triggers::StepRun).to have_received(:call).with(steps.second, commit).once
    end
  end
end
