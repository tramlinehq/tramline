# frozen_string_literal: true

require "rails_helper"

describe AutomaticUpdateRolloutJob do
  let(:play_store_integration) { instance_double(GooglePlayStoreIntegration) }
  let(:play_store_submission) { create(:play_store_submission, :prod_release) }

  before do
    allow_any_instance_of(ReleasePlatformRun).to receive(:store_provider).and_return(play_store_integration)
    allow(play_store_integration).to receive(:rollout_release).and_return(GitHub::Result.new { true })
  end

  context "when a staged play store rollout is created (rollout not initiated by user)" do
    let(:store_rollout) { create(:store_rollout, :play_store, :created, is_staged_rollout: true, automatic_rollout: true, store_submission: play_store_submission) }

    it "does not roll out the release" do
      described_class.new.perform(store_rollout.id, store_rollout.automatic_rollout_next_update_at, store_rollout.current_stage)
      expect(play_store_integration).not_to have_received(:rollout_release)
    end

    it "does not schedule rollout job" do
      expect {
        described_class.new.perform(store_rollout.id, store_rollout.automatic_rollout_next_update_at, store_rollout.current_stage)
      }.not_to change(described_class.jobs, :size)
    end
  end

  context "when a staged play store rollout is running" do
    let(:next_update_at) { PlayStoreRollout::AUTO_ROLLOUT_RUN_INTERVAL.from_now }
    let(:store_rollout) {
      create(:store_rollout,
        :play_store,
        :started,
        is_staged_rollout: true,
        automatic_rollout: true,
        store_submission: play_store_submission,
        current_stage: 1,
        automatic_rollout_next_update_at: next_update_at)
    }

    it "rolls out the release to next stage" do
      freeze_time do
        described_class.new.perform(store_rollout.id, next_update_at.to_i, 1)
        expect(play_store_integration).to have_received(:rollout_release)
        expect(store_rollout.reload.current_stage).to eq(2)
        expect(store_rollout.automatic_rollout_updated_at).to eq(Time.current)
        expect(store_rollout.automatic_rollout_next_update_at).to eq(PlayStoreRollout::AUTO_ROLLOUT_RUN_INTERVAL.from_now)
      end
    end

    it "schedules rollout job after AUTO_ROLLOUT_RUN_INTERVAL" do
      expect {
        described_class.new.perform(store_rollout.id, next_update_at.to_i, 1)
      }.to change(described_class.jobs, :size).by(1)
      expect(described_class.jobs.first["at"] - Time.current.to_f).to be_within(1.minute).of(PlayStoreRollout::AUTO_ROLLOUT_RUN_INTERVAL.to_i)
    end

    it "does not roll out the release if timestamp is stale" do
      stale_timestamp = (next_update_at - 1.minute).to_i
      described_class.new.perform(store_rollout.id, stale_timestamp, 1)
      expect(play_store_integration).not_to have_received(:rollout_release)
    end

    it "does not roll out the release if stage is stale" do
      described_class.new.perform(store_rollout.id, next_update_at.to_i, 0)
      expect(play_store_integration).not_to have_received(:rollout_release)
    end

    it "does not schedule rollout job if timestamp is stale" do
      stale_timestamp = (next_update_at - 1.minute).to_i
      expect {
        described_class.new.perform(store_rollout.id, stale_timestamp, 1)
      }.not_to change(described_class.jobs, :size)
    end

    it "does not schedule rollout job if stage is stale" do
      expect {
        described_class.new.perform(store_rollout.id, next_update_at.to_i, 0)
      }.not_to change(described_class.jobs, :size)
    end
  end

  context "when a staged play store rollout is paused" do
    let(:store_rollout) {
      create(:store_rollout,
        :play_store,
        :paused,
        is_staged_rollout: true,
        automatic_rollout: true,
        store_submission: play_store_submission,
        config: [1, 10, 100],
        current_stage: 0)
    }

    it "does not roll out the release" do
      described_class.new.perform(store_rollout.id, store_rollout.automatic_rollout_next_update_at, store_rollout.current_stage)
      expect(play_store_integration).not_to have_received(:rollout_release)
    end

    it "does not schedule rollout job" do
      expect {
        described_class.new.perform(store_rollout.id, store_rollout.automatic_rollout_next_update_at, store_rollout.current_stage)
      }.not_to change(described_class.jobs, :size)
    end
  end

  context "when a staged play store rollout is halted" do
    let(:store_rollout) {
      create(:store_rollout,
        :play_store,
        :halted,
        is_staged_rollout: true,
        automatic_rollout: true,
        store_submission: play_store_submission,
        config: [1, 10, 100],
        current_stage: 0)
    }

    before do
      allow_any_instance_of(ProductionRelease).to receive(:healthy?).and_return(true)
    end

    it "does not roll out the release" do
      described_class.new.perform(store_rollout.id, store_rollout.automatic_rollout_next_update_at, store_rollout.current_stage)
      expect(play_store_integration).not_to have_received(:rollout_release)
    end

    it "does not schedule rollout job" do
      expect {
        described_class.new.perform(store_rollout.id, store_rollout.automatic_rollout_next_update_at, store_rollout.current_stage)
      }.not_to change(described_class.jobs, :size)
    end
  end

  context "when a staged play store rollout is completed" do
    let(:store_rollout) { create(:store_rollout, :play_store, :completed, is_staged_rollout: true, automatic_rollout: true, store_submission: play_store_submission) }

    it "does not rollout the release" do
      described_class.new.perform(store_rollout.id, store_rollout.automatic_rollout_next_update_at, store_rollout.current_stage)
      expect(play_store_integration).not_to have_received(:rollout_release)
    end

    it "does not schedule rollout job" do
      expect {
        described_class.new.perform(store_rollout.id, store_rollout.automatic_rollout_next_update_at, store_rollout.current_stage)
      }.not_to change(described_class.jobs, :size)
    end
  end

  context "when a staged play store rollout does not have automatic rollout" do
    let(:store_rollout) { create(:store_rollout, :play_store, :started, is_staged_rollout: true, automatic_rollout: false, store_submission: play_store_submission) }

    it "does not rollout the release" do
      described_class.new.perform(store_rollout.id, store_rollout.automatic_rollout_next_update_at, store_rollout.current_stage)
      expect(play_store_integration).not_to have_received(:rollout_release)
    end

    it "does not schedule rollout job" do
      expect {
        described_class.new.perform(store_rollout.id, store_rollout.automatic_rollout_next_update_at, store_rollout.current_stage)
      }.not_to change(described_class.jobs, :size)
    end
  end

  context "when a non-staged play store rollout is created" do
    let(:store_rollout) { create(:store_rollout, :play_store, :created, is_staged_rollout: false, store_submission: play_store_submission) }

    it "does not rollout the release" do
      described_class.new.perform(store_rollout.id, store_rollout.automatic_rollout_next_update_at, store_rollout.current_stage)
      expect(play_store_integration).not_to have_received(:rollout_release)
    end

    it "does not schedule rollout job" do
      expect {
        described_class.new.perform(store_rollout.id, store_rollout.automatic_rollout_next_update_at, store_rollout.current_stage)
      }.not_to change(described_class.jobs, :size)
    end
  end
end
