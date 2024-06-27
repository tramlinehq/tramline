# frozen_string_literal: true

require "rails_helper"

describe PlayStoreRollout do
  describe "#start!" do
    let(:release_platform_run) { create(:release_platform_run) }
    let(:build) { create(:build) }
    let(:production_release) { create(:production_release, release_platform_run:) }
    let(:store_submission) { create(:play_store_submission, :prod_release, release_platform_run:, production_release:) }
    let(:rollout) { create(:store_rollout, :play_store, release_platform_run:, store_submission:) }

    it "informs the production release" do
      allow(production_release).to receive(:rollout_started!)
      rollout.start!
      expect(production_release).to have_received(:rollout_started!)
    end
  end

  describe "#move_to_next_stage!" do
    let(:release_platform_run) { create(:release_platform_run) }
    let(:build) { create(:build) }
    let(:production_release) { create(:production_release, release_platform_run:) }
    let(:store_submission) { create(:play_store_submission, :prod_release, release_platform_run:, production_release:) }
    let(:providable_dbl) { instance_double(GooglePlayStoreIntegration) }

    it "completes the rollout if no more stages left" do
      rollout = create(:store_rollout, :started, :play_store, release_platform_run:, store_submission:, config: [1, 80, 100], current_stage: 1)
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
      allow(rollout).to receive(:provider).and_return(providable_dbl)

      rollout.move_to_next_stage!
      expect(rollout.completed?).to be(true)
    end

    it "starts the rollout if it was created" do
      rollout = create(:store_rollout, :created, :play_store, release_platform_run:, store_submission:, config: [1, 80, 100])
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
      allow(rollout).to receive(:provider).and_return(providable_dbl)

      rollout.move_to_next_stage!
      expect(rollout.started?).to be(true)
    end

    it "promotes the deployment run with the next stage percentage" do
      rollout = create(:store_rollout, :started, :play_store, release_platform_run:, store_submission:, config: [1, 80, 100], current_stage: 1)
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
      allow(rollout).to receive(:provider).and_return(providable_dbl)

      rollout.move_to_next_stage!
      expect(providable_dbl).to(
        have_received(:rollout_release)
          .with(anything, anything, anything, 100, anything)
      )
    end

    it "updates the current stage with the next stage if promote succeeds" do
      rollout = create(:store_rollout, :started, :play_store, release_platform_run:, store_submission:, config: [1, 80, 100], current_stage: 1)
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
      allow(rollout).to receive(:provider).and_return(providable_dbl)

      rollout.move_to_next_stage!
      expect(rollout.current_stage).to eq(2)
    end

    it "does not update the current stage with the next stage if promote fails" do
      rollout = create(:store_rollout, :started, :play_store, release_platform_run:, store_submission:, config: [1, 80, 100], current_stage: 1)
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new { raise })
      allow(rollout).to receive(:provider).and_return(providable_dbl)

      rollout.move_to_next_stage!
      expect(rollout.errors?).to be(true)
      expect(rollout.current_stage).to eq(1)
    end

    it "can fail again on retry" do
      rollout = create(:store_rollout, :started, :play_store, release_platform_run:, store_submission:, config: [1, 80, 100], current_stage: 1)
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new { raise })
      allow(rollout).to receive(:provider).and_return(providable_dbl)

      # first attempt
      rollout.move_to_next_stage!
      expect(rollout.errors?).to be(true)

      # retry attempt
      rollout.move_to_next_stage!
      expect(rollout.errors?).to be(true)
    end
  end

  describe "#release_fully!" do
    let(:release_platform_run) { create(:release_platform_run) }
    let(:build) { create(:build) }
    let(:production_release) { create(:production_release, release_platform_run:) }
    let(:store_submission) { create(:play_store_submission, :prod_release, release_platform_run:, production_release:) }
    let(:providable_dbl) { instance_double(GooglePlayStoreIntegration) }

    it "does nothing if the rollout hasn't started" do
      rollout = create(:store_rollout, :created, :play_store, release_platform_run:, store_submission:)
      rollout.release_fully!

      expect(rollout.fully_released?).to be(false)
    end

    it "does nothing if the rollout is completed" do
      rollout = create(:store_rollout, :completed, :play_store, release_platform_run:, store_submission:)
      rollout.release_fully!

      expect(rollout.fully_released?).to be(false)
    end

    it "does nothing if the rollout is halted" do
      rollout = create(:store_rollout, :halted, :play_store, release_platform_run:, store_submission:)
      rollout.release_fully!

      expect(rollout.fully_released?).to be(false)
    end

    it "informs the production release about rollout complete" do
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)

      rollout = create(:store_rollout, :started, :play_store, release_platform_run:, store_submission:)
      allow(rollout).to receive(:provider).and_return(providable_dbl)
      allow(rollout).to receive(:production_release).and_return(production_release)
      allow(production_release).to receive(:rollout_complete!)

      rollout.release_fully!

      expect(production_release).to have_received(:rollout_complete!)
      expect(rollout.fully_released?).to be(true)
    end

    it "does not inform the production release when rollout cannot complete" do
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new { raise })

      rollout = create(:store_rollout, :started, :play_store, release_platform_run:, store_submission:)
      allow(rollout).to receive(:provider).and_return(providable_dbl)
      allow(rollout.production_release).to receive(:rollout_complete!)
      allow(rollout).to receive(:production_release).and_return(production_release)

      rollout.release_fully!

      expect(rollout.production_release).not_to have_received(:rollout_complete!)
      expect(rollout.fully_released?).to be(false)
    end
  end

  describe "#halt_release!" do
    let(:release_platform_run) { create(:release_platform_run) }
    let(:build) { create(:build) }
    let(:production_release) { create(:production_release, release_platform_run:) }
    let(:store_submission) { create(:play_store_submission, :prod_release, release_platform_run:, production_release:) }
    let(:providable_dbl) { instance_double(GooglePlayStoreIntegration) }

    it "halts the rollout if started" do
      rollout = create(:store_rollout, :started, :play_store, release_platform_run:, store_submission:)
      allow(providable_dbl).to receive(:halt_release).and_return(GitHub::Result.new)
      allow(rollout).to receive(:provider).and_return(providable_dbl)

      rollout.halt_release!

      expect(rollout.halted?).to be(true)
    end

    it "does nothing if the rollout hasn't started" do
      rollout = create(:store_rollout, :created, :play_store, release_platform_run:, store_submission:)
      allow(providable_dbl).to receive(:halt_release).and_return(GitHub::Result.new)
      allow(rollout).to receive(:provider).and_return(providable_dbl)

      rollout.halt_release!

      expect(rollout.halted?).to be(false)
    end

    it "does nothing if the rollout is completed" do
      rollout = create(:store_rollout, :completed, :play_store, release_platform_run:, store_submission:)
      allow(providable_dbl).to receive(:halt_release).and_return(GitHub::Result.new)
      allow(rollout).to receive(:provider).and_return(providable_dbl)

      rollout.halt_release!

      expect(rollout.halted?).to be(false)
    end
  end

  describe "#resume_release!" do
    let(:release_platform_run) { create(:release_platform_run) }
    let(:build) { create(:build) }
    let(:production_release) { create(:production_release, release_platform_run:) }
    let(:store_submission) { create(:play_store_submission, :prod_release, release_platform_run:, production_release:) }
    let(:providable_dbl) { instance_double(GooglePlayStoreIntegration) }

    it "resumes the rollout if halted" do
      rollout = create(:store_rollout, :halted, :play_store, release_platform_run:, store_submission:, config: [1, 80], current_stage: 0)
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
      allow(rollout).to receive(:provider).and_return(providable_dbl)
      rollout.resume_release!
      expect(rollout.started?).to be(true)
    end

    it "does not resume the rollout if store call fails" do
      rollout = create(:store_rollout, :halted, :play_store, release_platform_run:, store_submission:, config: [1, 80], current_stage: 0)
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new { raise })
      allow(rollout).to receive(:provider).and_return(providable_dbl)
      rollout.resume_release!
      expect(rollout.halted?).to be(true)
      expect(rollout.errors?).to be(true)
    end
  end
end
