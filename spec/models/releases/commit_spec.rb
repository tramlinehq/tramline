require "rails_helper"

describe Releases::Commit, type: :model do
  it "has valid factory" do
    expect(create(:releases_commit)).to be_valid
  end

  describe "#trigger_step_runs" do
    let(:active_train) { create(:releases_train, :active) }

    it "does it for the first step run if first commit" do
      train_run = create(:releases_train_run, train: active_train)
      create(:releases_step, :with_deployment, train: active_train)

      allow(Triggers::StepRun).to receive(:call)

      create(:releases_commit, train: active_train, train_run: train_run)

      expect(Triggers::StepRun).to have_received(:call)
    end

    xit "does it for all steps until the currently running one" do
      # train_run = create(:releases_train_run, train: active_train)
      # create(:releases_step, :with_deployment, train: active_train)
      #
      # allow(Triggers::StepRun).to receive(:call)
      #
      # create(:releases_commit, train: active_train, train_run: train_run)
      #
      # expect(Triggers::StepRun).to have_received(:call)
    end
  end
end
