require "rails_helper"

describe StagedRollout do
  it "has a valid factory" do
    expect(create(:staged_rollout)).to be_valid
  end

  describe "#start!" do
    let(:deployment_run) { create(:deployment_run, :rollout_started, :with_staged_rollout) }
    let(:staged_rollout) { create(:staged_rollout, :created, deployment_run:) }

    it "does not start if deployment run is not rolloutable" do
      deployment_run.release.update(status: "stopped")

      expect { staged_rollout.start! }.to raise_error(AASM::InvalidTransition)
    end
  end

  describe "#retry!" do
    let(:deployment_run) { create(:deployment_run, :rollout_started, :with_staged_rollout) }
    let(:staged_rollout) { create(:staged_rollout, :failed, deployment_run:) }

    it "does not start if deployment run is not rolloutable" do
      deployment_run.release.update(status: "stopped")

      expect { staged_rollout.retry! }.to raise_error(AASM::InvalidTransition)
    end
  end

  describe "#halt!" do
    let(:deployment_run) { create(:deployment_run, :rollout_started, :with_staged_rollout) }
    let(:staged_rollout) { create(:staged_rollout, :failed, deployment_run:) }

    it "does not start if deployment run is not rolloutable" do
      deployment_run.release.update(status: "stopped")

      expect { staged_rollout.halt! }.to raise_error(AASM::InvalidTransition)
    end
  end

  describe "#complete!" do
    it "transitions state" do
      rollout = create(:staged_rollout, :started)

      rollout.complete!

      expect(rollout.reload.completed?).to be(true)
    end

    it "completes the deployment run" do
      rollout = create(:staged_rollout, :started)

      rollout.complete!
      rollout.reload

      expect(rollout.completed?).to be(true)
      expect(rollout.deployment_run.released?).to be(true)
    end
  end

  describe "#halt_release!" do
    let(:deployment_run) { create(:deployment_run, :with_staged_rollout, :rollout_started) }
    let(:providable_dbl) { instance_double(GooglePlayStoreIntegration) }
    let(:rollout) { create(:staged_rollout, :started, current_stage: 0, deployment_run: deployment_run) }

    before do
      allow_any_instance_of(DeploymentRun).to receive(:provider).and_return(providable_dbl)
    end

    it "does nothing if the rollout hasn't started" do
      unrolled_rollout = create(:staged_rollout, :created, deployment_run: deployment_run)
      unrolled_rollout.halt_release!

      expect(rollout.reload.stopped?).to be(false)
    end

    it "does nothing if the rollout is completed" do
      unrolled_rollout = create(:staged_rollout, :completed, deployment_run: deployment_run)
      unrolled_rollout.halt_release!

      expect(rollout.reload.stopped?).to be(false)
    end

    it "transitions state" do
      allow(providable_dbl).to receive(:halt_release).and_return(GitHub::Result.new)
      rollout.halt_release!

      expect(rollout.reload.stopped?).to be(true)
    end

    it "completes the deployment run if halt succeeds" do
      allow(providable_dbl).to receive(:halt_release).and_return(GitHub::Result.new)
      rollout.halt_release!

      expect(rollout.deployment_run.reload.released?).to be(true)
    end

    it "does not complete the deployment run if halt fails" do
      allow(providable_dbl).to receive(:halt_release).and_return(GitHub::Result.new { raise })
      rollout.halt_release!

      expect(rollout.deployment_run.reload.released?).to be(false)
      expect(rollout.reload.stopped?).to be(false)
    end
  end

  describe "#last_rollout_percentage" do
    it "returns the rollout value for the current stage" do
      rollout = create(:staged_rollout, :started, config: [1, 80, 100], current_stage: 1)

      expect(rollout.last_rollout_percentage).to eq(80)
    end

    it "returns nothing if rollout has not started" do
      rollout = create(:staged_rollout, :created, config: [1, 80, 100])

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
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
      rollout = create(:staged_rollout, :started, deployment_run:, config: [1, 80, 100], current_stage: 1)

      rollout.move_to_next_stage!
      expect(rollout.reload.completed?).to be(true)
    end

    it "starts the staged rollout if it was created" do
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
      rollout = create(:staged_rollout, :created, deployment_run:, config: [1, 80, 100])

      rollout.move_to_next_stage!
      expect(providable_dbl).to have_received(:rollout_release).with(anything, anything, anything, 1)
      expect(rollout.reload.started?).to be(true)
    end

    it "promotes the deployment run with the next stage percentage" do
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
      rollout = create(:staged_rollout, :started, deployment_run:, config: [1, 80, 100], current_stage: 1)

      rollout.move_to_next_stage!
      expect(providable_dbl).to have_received(:rollout_release).with(anything, anything, anything, 100)
    end

    it "updates the current stage with the next stage if promote succeeds" do
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
      rollout = create(:staged_rollout, :started, deployment_run: deployment_run, config: [1, 80, 100], current_stage: 1)

      rollout.move_to_next_stage!
      expect(rollout.reload.current_stage).to eq(2)
    end

    it "does not update the current stage with the next stage if promote fails" do
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new { raise })
      rollout = create(:staged_rollout, :started, deployment_run: deployment_run, config: [1, 80, 100], current_stage: 1)

      rollout.move_to_next_stage!
      expect(rollout.reload.failed?).to be(true)
      expect(rollout.reload.current_stage).to eq(1)
    end

    it "is retriable on failure" do
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
      rollout = create(:staged_rollout, :failed, deployment_run:, config: [1, 80, 100], current_stage: 1)

      rollout.move_to_next_stage!
      expect(rollout.reload.completed?).to be(true)
    end

    it "can fail again on retry" do
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new { raise })
      rollout = create(:staged_rollout, :started, deployment_run:, config: [1, 80, 100], current_stage: 1)

      # first attempt
      rollout.move_to_next_stage!
      expect(rollout.reload.failed?).to be(true)

      # retry attempt
      rollout.move_to_next_stage!
      expect(rollout.reload.failed?).to be(true)
    end
  end
end
