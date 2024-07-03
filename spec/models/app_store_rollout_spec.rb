# frozen_string_literal: true

require "rails_helper"

describe AppStoreRollout do
  describe "#start!" do
    let(:release_platform_run) { create(:release_platform_run) }
    let(:production_release) { create(:production_release, release_platform_run:) }
    let(:store_submission) { create(:app_store_submission, release_platform_run:, parent_release: production_release) }
    let(:rollout) { create(:store_rollout, :app_store, release_platform_run:, store_submission:) }

    it "informs the production release" do
      allow(production_release).to receive(:rollout_started!)
      allow(StoreRollouts::AppStore::FindLiveReleaseJob).to receive(:perform_async)

      rollout.start!

      expect(production_release).to have_received(:rollout_started!)
      expect(StoreRollouts::AppStore::FindLiveReleaseJob).to have_received(:perform_async).with(rollout.id).once
    end
  end

  describe "#release_fully!" do
    let(:release_info) {
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
    let(:release_platform_run) { create(:release_platform_run) }
    let(:production_release) { create(:production_release, release_platform_run:) }
    let(:store_submission) { create(:app_store_submission, release_platform_run:, parent_release: production_release) }
    let(:providable_dbl) { instance_double(AppStoreIntegration) }

    it "does nothing if the rollout hasn't started" do
      rollout = create(:store_rollout, :created, :app_store, release_platform_run:, store_submission:)
      rollout.release_fully!

      expect(rollout.fully_released?).to be(false)
    end

    it "does nothing if the rollout is completed" do
      rollout = create(:store_rollout, :completed, :app_store, release_platform_run:, store_submission:)
      rollout.release_fully!

      expect(rollout.fully_released?).to be(false)
    end

    it "does nothing if the rollout is halted" do
      rollout = create(:store_rollout, :halted, :app_store, release_platform_run:, store_submission:)
      rollout.release_fully!

      expect(rollout.fully_released?).to be(false)
    end

    it "informs the production release about rollout complete" do
      allow(providable_dbl).to receive(:complete_phased_release).and_return(GitHub::Result.new { release_info })

      rollout = create(:store_rollout, :started, :app_store, release_platform_run:, store_submission:)
      allow(rollout).to receive(:provider).and_return(providable_dbl)
      allow(rollout).to receive(:parent_release).and_return(production_release)
      allow(production_release).to receive(:rollout_complete!)

      rollout.release_fully!

      expect(production_release).to have_received(:rollout_complete!)
      expect(rollout.fully_released?).to be(true)
    end

    it "does not inform the production release when rollout cannot complete" do
      allow(providable_dbl).to receive(:complete_phased_release).and_return(GitHub::Result.new { raise })

      rollout = create(:store_rollout, :started, :app_store, release_platform_run:, store_submission:)
      allow(rollout).to receive(:provider).and_return(providable_dbl)
      allow(rollout).to receive(:parent_release).and_return(production_release)
      allow(production_release).to receive(:rollout_complete!)

      rollout.release_fully!

      expect(production_release).not_to have_received(:rollout_complete!)
      expect(rollout.fully_released?).to be(false)
    end
  end

  describe "#halt_release!" do
    let(:release_info) {
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
    let(:release_platform_run) { create(:release_platform_run) }
    let(:production_release) { create(:production_release, release_platform_run:) }
    let(:store_submission) { create(:app_store_submission, release_platform_run:, parent_release: production_release) }
    let(:providable_dbl) { instance_double(AppStoreIntegration) }

    it "halts the rollout if started" do
      rollout = create(:store_rollout, :started, :app_store, release_platform_run:, store_submission:)
      allow(providable_dbl).to receive(:halt_phased_release).and_return(GitHub::Result.new { release_info })
      allow(rollout).to receive(:provider).and_return(providable_dbl)

      rollout.halt_release!

      expect(rollout.halted?).to be(true)
    end

    it "does nothing if the rollout hasn't started" do
      rollout = create(:store_rollout, :created, :app_store, release_platform_run:, store_submission:)
      allow(providable_dbl).to receive(:halt_phased_release).and_return(GitHub::Result.new { release_info })
      allow(rollout).to receive(:provider).and_return(providable_dbl)

      rollout.halt_release!

      expect(rollout.halted?).to be(false)
    end

    it "does nothing if the rollout is completed" do
      rollout = create(:store_rollout, :completed, :app_store, release_platform_run:, store_submission:)
      allow(providable_dbl).to receive(:halt_phased_release).and_return(GitHub::Result.new { release_info })
      allow(rollout).to receive(:provider).and_return(providable_dbl)

      rollout.halt_release!

      expect(rollout.halted?).to be(false)
    end
  end

  describe "#pause_release!" do
    let(:release_info) {
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
    let(:release_platform_run) { create(:release_platform_run) }
    let(:production_release) { create(:production_release, release_platform_run:) }
    let(:store_submission) { create(:app_store_submission, release_platform_run:, parent_release: production_release) }
    let(:providable_dbl) { instance_double(AppStoreIntegration) }

    it "resumes the rollout if halted" do
      rollout = create(:store_rollout, :started, :app_store, release_platform_run:, store_submission:, config: [1, 80], current_stage: 0)
      allow(providable_dbl).to receive(:pause_phased_release).and_return(GitHub::Result.new { release_info })
      allow(rollout).to receive(:provider).and_return(providable_dbl)
      rollout.pause_release!
      expect(rollout.paused?).to be(true)
    end

    it "does not resume the rollout if store call fails" do
      rollout = create(:store_rollout, :started, :app_store, release_platform_run:, store_submission:, config: [1, 80], current_stage: 0)
      allow(providable_dbl).to receive(:pause_phased_release).and_return(GitHub::Result.new { raise })
      allow(rollout).to receive(:provider).and_return(providable_dbl)
      rollout.pause_release!
      expect(rollout.paused?).to be(false)
      expect(rollout.errors?).to be(true)
    end
  end

  describe "#resume_release!" do
    let(:release_info) {
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
    let(:release_platform_run) { create(:release_platform_run) }
    let(:production_release) { create(:production_release, release_platform_run:) }
    let(:store_submission) { create(:app_store_submission, release_platform_run:, parent_release: production_release) }
    let(:providable_dbl) { instance_double(AppStoreIntegration) }

    it "resumes the rollout if paused" do
      rollout = create(:store_rollout, :paused, :app_store, release_platform_run:, store_submission:, config: [1, 80], current_stage: 0)
      allow(providable_dbl).to receive(:resume_phased_release).and_return(GitHub::Result.new { release_info })
      allow(rollout).to receive(:provider).and_return(providable_dbl)
      rollout.resume_release!
      expect(rollout.started?).to be(true)
    end

    it "does not resume the rollout if store call fails" do
      rollout = create(:store_rollout, :paused, :app_store, release_platform_run:, store_submission:, config: [1, 80], current_stage: 0)
      allow(providable_dbl).to receive(:resume_phased_release).and_return(GitHub::Result.new { raise })
      allow(rollout).to receive(:provider).and_return(providable_dbl)
      rollout.resume_release!
      expect(rollout.paused?).to be(true)
      expect(rollout.errors?).to be(true)
    end
  end
end
