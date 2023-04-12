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

    it "does not retry if deployment run is not rolloutable" do
      deployment_run.release.update(status: "stopped")

      expect { staged_rollout.retry! }.to raise_error(AASM::InvalidTransition)
    end
  end

  describe "#halt!" do
    let(:deployment_run) { create(:deployment_run, :rollout_started, :with_staged_rollout) }
    let(:staged_rollout) { create(:staged_rollout, :failed, deployment_run:) }

    it "does not halt if deployment run is not rolloutable" do
      deployment_run.release.update(status: "stopped")

      expect { staged_rollout.halt! }.to raise_error(AASM::InvalidTransition)
    end
  end

  describe "#complete!" do
    it "transitions state" do
      rollout = create(:staged_rollout, :started, current_stage: 1)

      rollout.complete!

      expect(rollout.reload.completed?).to be(true)
    end

    it "completes the deployment run" do
      rollout = create(:staged_rollout, :started, current_stage: 1)

      rollout.complete!
      rollout.reload

      expect(rollout.completed?).to be(true)
      expect(rollout.deployment_run.released?).to be(true)
    end
  end

  describe "#halt_release!" do
    it "does nothing if the rollout hasn't started" do
      unrolled_rollout = create(:staged_rollout, :created)
      unrolled_rollout.halt_release!

      expect(unrolled_rollout.reload.stopped?).to be(false)
    end

    it "does nothing if the rollout is completed" do
      unrolled_rollout = create(:staged_rollout, :completed)
      unrolled_rollout.halt_release!

      expect(unrolled_rollout.reload.stopped?).to be(false)
    end

    context "when google play store" do
      let(:deployment_run) { create(:deployment_run, :with_staged_rollout, :rollout_started) }
      let(:providable_dbl) { instance_double(GooglePlayStoreIntegration) }
      let(:rollout) { create(:staged_rollout, :started, current_stage: 0, deployment_run: deployment_run) }

      before do
        allow_any_instance_of(DeploymentRun).to receive(:provider).and_return(providable_dbl)
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

    context "when app store" do
      let(:deployment_run) {
        create_deployment_run_for_ios(:with_staged_rollout, :rollout_started, :with_external_release,
          deployment_traits: [:with_app_store, :with_phased_release],
          step_trait: :release)
      }
      let(:rollout) { create(:staged_rollout, :started, current_stage: 0, deployment_run: deployment_run) }
      let(:providable_dbl) { instance_double(AppStoreIntegration) }

      before do
        allow_any_instance_of(DeploymentRun).to receive(:provider).and_return(providable_dbl)
      end

      it "halts the release in store" do
        allow(providable_dbl).to receive(:halt_phased_release).and_return(GitHub::Result.new)
        rollout.halt_release!

        expect(providable_dbl).to have_received(:halt_phased_release)
      end

      it "marks rollout as halted" do
        allow(providable_dbl).to receive(:halt_phased_release).and_return(GitHub::Result.new)
        rollout.halt_release!

        expect(rollout.reload.stopped?).to be(true)
      end

      it "marks deployment run is completed" do
        allow(providable_dbl).to receive(:halt_phased_release).and_return(GitHub::Result.new)
        rollout.halt_release!

        expect(deployment_run.reload.released?).to be(true)
      end

      it "does not complete the deployment run if rollout fails" do
        allow(providable_dbl).to receive(:halt_phased_release).and_return(GitHub::Result.new { raise })
        rollout.halt_release!

        expect(rollout.deployment_run.reload.released?).to be(false)
        expect(rollout.reload.stopped?).to be(false)
      end
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
    let(:release_metadata) { deployment_run.step_run.train_run.release_metadata }
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
      expect(providable_dbl).to(
        have_received(:rollout_release)
          .with(anything, anything, anything, 1, [release_metadata])
      )
      expect(rollout.reload.started?).to be(true)
    end

    it "promotes the deployment run with the next stage percentage" do
      allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
      rollout = create(:staged_rollout, :started, deployment_run:, config: [1, 80, 100], current_stage: 1)

      rollout.move_to_next_stage!
      expect(providable_dbl).to(
        have_received(:rollout_release)
          .with(anything, anything, anything, 100, [release_metadata])
      )
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

  describe "#fully_release!" do
    let(:deployment_run) { create(:deployment_run, :with_staged_rollout, :rollout_started) }
    let(:rollout) { create(:staged_rollout, :started, current_stage: 0, deployment_run: deployment_run) }

    it "does nothing if the rollout hasn't started" do
      unrolled_rollout = create(:staged_rollout, :created, deployment_run: deployment_run)
      unrolled_rollout.fully_release!

      expect(rollout.reload.fully_released?).to be(false)
    end

    it "does nothing if the rollout is completed" do
      unrolled_rollout = create(:staged_rollout, :completed, deployment_run: deployment_run)
      unrolled_rollout.fully_release!

      expect(rollout.reload.fully_released?).to be(false)
    end

    it "does nothing if the rollout is stopped" do
      unrolled_rollout = create(:staged_rollout, :stopped, deployment_run: deployment_run)
      unrolled_rollout.fully_release!

      expect(rollout.reload.fully_released?).to be(false)
    end

    context "when google play store" do
      let(:providable_dbl) { instance_double(GooglePlayStoreIntegration) }

      before do
        allow_any_instance_of(DeploymentRun).to receive(:provider).and_return(providable_dbl)
      end

      it "transitions state" do
        allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
        rollout.fully_release!

        expect(rollout.reload.fully_released?).to be(true)
      end

      it "completes the deployment run if rollout succeeds" do
        allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
        rollout.fully_release!

        expect(rollout.deployment_run.reload.released?).to be(true)
      end

      it "does not complete the deployment run if rollout fails" do
        allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new { raise })
        rollout.fully_release!

        expect(rollout.deployment_run.reload.released?).to be(false)
        expect(rollout.reload.fully_released?).to be(false)
      end
    end

    context "when app store" do
      let(:deployment_run) {
        create_deployment_run_for_ios(
          :rollout_started,
          :with_external_release,
          deployment_traits: [:with_app_store, :with_phased_release],
          step_trait: :release
        )
      }
      let(:rollout) { create(:staged_rollout, :started, current_stage: 0, deployment_run: deployment_run) }
      let(:providable_dbl) { instance_double(AppStoreIntegration) }
      let(:live_release_info) {
        AppStoreIntegration::AppStoreReleaseInfo.new(
          {
            external_id: "bd31faa6-6a9a-4958-82de-d271ddc639a8",
            name: "1.2.0",
            build_number: 9012,
            added_at: 1.day.ago,
            status: "READY_FOR_SALE",
            phased_release_day: 1,
            phased_release_status: "COMPLETE"
          }
        )
      }

      before do
        allow_any_instance_of(DeploymentRun).to receive(:provider).and_return(providable_dbl)
      end

      it "transitions state" do
        allow(providable_dbl).to receive(:complete_phased_release).and_return(GitHub::Result.new { live_release_info })
        rollout.fully_release!

        expect(rollout.reload.fully_released?).to be(true)
      end

      it "completes the deployment run if rollout succeeds" do
        allow(providable_dbl).to receive(:complete_phased_release).and_return(GitHub::Result.new { live_release_info })
        rollout.fully_release!

        expect(rollout.deployment_run.reload.released?).to be(true)
      end

      it "does not complete the deployment run if rollout fails" do
        allow(providable_dbl).to receive(:complete_phased_release).and_return(GitHub::Result.new { raise })
        rollout.fully_release!

        expect(rollout.deployment_run.reload.released?).to be(false)
        expect(rollout.reload.fully_released?).to be(false)
      end
    end
  end

  describe "#pause_release!" do
    let(:deployment_run) {
      create_deployment_run_for_ios(:with_staged_rollout, :rollout_started, :with_external_release,
        deployment_traits: [:with_app_store, :with_phased_release],
        step_trait: :release)
    }
    let(:rollout) { create(:staged_rollout, :started, current_stage: 0, deployment_run: deployment_run) }
    let(:providable_dbl) { instance_double(AppStoreIntegration) }
    let(:paused_release_info) {
      AppStoreIntegration::AppStoreReleaseInfo.new(
        {
          external_id: "bd31faa6-6a9a-4958-82de-d271ddc639a8",
          name: "1.2.0",
          build_number: 9012,
          added_at: 1.day.ago,
          status: "READY_FOR_SALE",
          phased_release_day: 1,
          phased_release_status: "INACTIVE"
        }
      )
    }

    before do
      allow_any_instance_of(DeploymentRun).to receive(:provider).and_return(providable_dbl)
    end

    [:created, :completed, :stopped, :failed, :fully_released, :paused].each do |trait|
      it "does nothing if the rollout hasn't #{trait}" do
        allow(providable_dbl).to receive(:pause_phased_release)
        unrolled_rollout = create(:staged_rollout, trait, deployment_run: deployment_run)
        unrolled_rollout.pause_release!

        expect(providable_dbl).not_to have_received(:pause_phased_release)
      end
    end

    it "pauses the release in store" do
      allow(providable_dbl).to receive(:pause_phased_release).and_return(GitHub::Result.new { paused_release_info })
      rollout.pause_release!

      expect(providable_dbl).to have_received(:pause_phased_release)
    end

    it "marks the rollout as paused" do
      allow(providable_dbl).to receive(:pause_phased_release).and_return(GitHub::Result.new { paused_release_info })
      rollout.pause_release!

      expect(rollout.reload.paused?).to be(true)
    end

    it "does not pause the rollout if store call fails" do
      allow(providable_dbl).to receive(:pause_phased_release).and_return(GitHub::Result.new { raise })
      rollout.pause_release!

      expect(rollout.reload.paused?).to be(false)
    end

    it "does nothing when controllable rollout" do
      goog_deployment_run = create_deployment_run_for_ios(:with_staged_rollout, :rollout_started,
        deployment_traits: [:with_google_play_store],
        step_trait: :release)
      controllable_rollout = create(:staged_rollout, :started, current_stage: 0, deployment_run: goog_deployment_run)
      controllable_rollout.pause_release!

      expect(controllable_rollout.reload.paused?).to be(false)
    end
  end

  describe "#resume_release!" do
    let(:deployment_run) {
      create_deployment_run_for_ios(:with_staged_rollout, :rollout_started, :with_external_release,
        deployment_traits: [:with_app_store, :with_phased_release],
        step_trait: :release)
    }
    let(:rollout) { create(:staged_rollout, :paused, current_stage: 0, deployment_run: deployment_run, config: AppStoreIntegration::DEFAULT_PHASED_RELEASE_SEQUENCE) }
    let(:providable_dbl) { instance_double(AppStoreIntegration) }
    let(:resumed_release_info) {
      AppStoreIntegration::AppStoreReleaseInfo.new(
        {
          external_id: "bd31faa6-6a9a-4958-82de-d271ddc639a8",
          name: "1.2.0",
          build_number: 9012,
          added_at: 1.day.ago,
          status: "READY_FOR_SALE",
          phased_release_day: 2,
          phased_release_status: "ACTIVE"
        }
      )
    }

    before do
      allow_any_instance_of(DeploymentRun).to receive(:provider).and_return(providable_dbl)
    end

    [:created, :started, :completed, :stopped, :failed, :fully_released].each do |trait|
      it "does nothing if the rollout hasn't #{trait}" do
        allow(providable_dbl).to receive(:resume_phased_release)
        unrolled_rollout = create(:staged_rollout, trait, deployment_run: deployment_run)
        unrolled_rollout.resume_release!

        expect(providable_dbl).not_to have_received(:resume_phased_release)
      end
    end

    it "resumes the release in store" do
      allow(providable_dbl).to receive(:resume_phased_release).and_return(GitHub::Result.new { resumed_release_info })
      rollout.resume_release!

      expect(providable_dbl).to have_received(:resume_phased_release)
    end

    it "marks the rollout as started" do
      allow(providable_dbl).to receive(:resume_phased_release).and_return(GitHub::Result.new { resumed_release_info })
      rollout.resume_release!

      expect(rollout.reload.started?).to be(true)
    end

    it "does not mark the rollout as started if completed" do
      completed_release_info = AppStoreIntegration::AppStoreReleaseInfo.new(
        {
          external_id: "bd31faa6-6a9a-4958-82de-d271ddc639a8",
          name: "1.2.0",
          build_number: 9012,
          added_at: 1.day.ago,
          status: "READY_FOR_SALE",
          phased_release_day: 8,
          phased_release_status: "COMPLETED"
        }
      )
      allow(providable_dbl).to receive(:resume_phased_release).and_return(GitHub::Result.new { completed_release_info })
      rollout.resume_release!

      expect(rollout.reload.completed?).to be(true)
    end

    it "does not resume the rollout if store call fails" do
      allow(providable_dbl).to receive(:resume_phased_release).and_return(GitHub::Result.new { raise })
      rollout.resume_release!

      expect(rollout.reload.paused?).to be(true)
    end

    it "does nothing when controllable rollout" do
      goog_deployment_run = create_deployment_run_for_ios(:with_staged_rollout, :rollout_started,
        deployment_traits: [:with_google_play_store],
        step_trait: :release)
      controllable_rollout = create(:staged_rollout, :paused, current_stage: 0, deployment_run: goog_deployment_run)
      controllable_rollout.resume_release!

      expect(controllable_rollout.reload.paused?).to be(true)
    end
  end
end
