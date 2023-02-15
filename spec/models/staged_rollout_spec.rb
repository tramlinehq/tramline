require "rails_helper"

describe StagedRollout do
  it "has a valid factory" do
    expect(create(:staged_rollout)).to be_valid
  end

  describe "#complete!" do
    it "transitions state" do
      rollout = create(:staged_rollout)

      rollout.complete!

      expect(rollout.reload.completed?).to be(true)
    end

    it "completes the deployment run" do
      rollout = create(:staged_rollout)

      rollout.complete!
      rollout.reload

      expect(rollout.completed?).to be(true)
      expect(rollout.deployment_run.released?).to be(true)
    end
  end

  describe "#halt!" do
    it "transitions state" do
      rollout = create(:staged_rollout)

      rollout.halt!

      expect(rollout.reload.stopped?).to be(true)
    end

    it "completes the deployment run" do
      rollout = create(:staged_rollout)

      rollout.halt!
      rollout.reload

      expect(rollout.stopped?).to be(true)
      expect(rollout.deployment_run.released?).to be(true)
    end
  end

  describe "#last_rollout_percentage" do
    it "returns the rollout value for the current stage" do
      rollout = create(:staged_rollout, config: [1, 80, 100], current_stage: 1)

      expect(rollout.last_rollout_percentage).to eq(80)
    end

    it "returns nothing if current stage is unset" do
      rollout = create(:staged_rollout, config: [1, 80, 100], current_stage: nil)

      expect(rollout.last_rollout_percentage).to be_nil
    end
  end

  describe "#move_to_next_stage!" do
    let(:deployment_run) { create(:deployment_run, :with_staged_rollout, :rollout_started) }
    let(:providable_dbl) { instance_double(GooglePlayStoreIntegration) }

    before do
      allow_any_instance_of(DeploymentRun).to receive(:provider).and_return(providable_dbl)
    end

    it "completes the rollout if no more stages left" do
      allow(providable_dbl).to receive(:create_release).and_return(GitHub::Result.new)
      rollout = create(:staged_rollout, :started, deployment_run:, config: [1, 80, 100], current_stage: 1)

      rollout.move_to_next_stage!
      expect(rollout.reload.completed?).to be(true)
    end

    it "promotes the deployment run with the next stage percentage" do
      allow(providable_dbl).to receive(:create_release).and_return(GitHub::Result.new)
      rollout = create(:staged_rollout, :started, deployment_run:, config: [1, 80, 100], current_stage: 1)

      rollout.move_to_next_stage!
      expect(providable_dbl).to have_received(:create_release).with(anything, anything, anything, 100)
    end

    it "updates the current stage with the next stage if promote succeeds" do
      allow(providable_dbl).to receive(:create_release).and_return(GitHub::Result.new)
      rollout = create(:staged_rollout, deployment_run: deployment_run, config: [1, 80, 100], current_stage: 1)

      rollout.move_to_next_stage!
      expect(rollout.reload.current_stage).to eq(2)
    end

    it "does not update the current stage with the next stage if promote fails" do
      allow(providable_dbl).to receive(:create_release).and_return(GitHub::Result.new { raise })
      rollout = create(:staged_rollout, deployment_run: deployment_run, config: [1, 80, 100], current_stage: 1)

      rollout.move_to_next_stage!
      expect(rollout.reload.current_stage).to eq(1)
      expect(rollout.reload.completed?).to be(false)
    end
  end
end
