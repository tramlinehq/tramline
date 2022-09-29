require "rails_helper"

RSpec.describe Releases::Step::Run, type: :model do
  it "has valid spec" do
    expect(create(:releases_step_run)).to be_valid
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

    it "is false when it is the first deployment or no other deployment runs have happened" do
      step = create(:releases_step, train: active_train)
      step_run = create(:releases_step_run, step: step)
      deployment = create(:deployment, step: step)
      _active_train_run = create(:releases_train_run, train: active_train, status: "on_track")

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
