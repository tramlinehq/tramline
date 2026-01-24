require "rails_helper"

describe VerifyAutomaticRolloutJob do
  let(:play_store_submission) { create(:play_store_submission, :prod_release) }

  before do
    allow(AutomaticUpdateRolloutJob).to receive(:perform_async)
  end

  context "when a staged play store rollout with automatic rollout is created" do
    before do
      create(:store_rollout, :play_store, :created, is_staged_rollout: true, automatic_rollout: true, store_submission: play_store_submission)
    end

    it "does not call enqueue IncreaseHealthyReleaseRolloutJob" do
      described_class.new.perform
      expect(AutomaticUpdateRolloutJob).not_to have_received(:perform_async)
    end
  end

  context "when a staged play store rollout without automatic rollout is in first stage" do
    before do
      create(:store_rollout, :play_store, :started, is_staged_rollout: true, automatic_rollout: false, store_submission: play_store_submission, current_stage: 1)
    end

    it "does not call enqueue IncreaseHealthyReleaseRolloutJob" do
      described_class.new.perform
      expect(AutomaticUpdateRolloutJob).not_to have_received(:perform_async)
    end
  end

  context "when a staged play store rollout with automatic rollout is in first stage and not rolled out" do
    let(:store_rollout) { create(:store_rollout, :play_store, :started, is_staged_rollout: true, automatic_rollout: true, store_submission: play_store_submission, current_stage: 1, automatic_rollout_updated_at: 24.hours.ago, automatic_rollout_next_update_at: 10.minutes.ago) }

    it "enqueues AutomaticUpdateRolloutJob" do
      store_rollout # ensure record exists before perform
      described_class.new.perform
      expect(AutomaticUpdateRolloutJob).to have_received(:perform_async).with(store_rollout.id, store_rollout.automatic_rollout_next_update_at.to_i, store_rollout.current_stage)
    end
  end

  context "when a staged play store rollout with automatic rollout is in second stage and rolled out" do
    before do
      create(:store_rollout, :play_store, :started, is_staged_rollout: true, automatic_rollout: true, store_submission: play_store_submission, current_stage: 2, automatic_rollout_updated_at: 4.minutes.ago, automatic_rollout_next_update_at: 24.hours.from_now)
    end

    it "does not enqueue IncreaseHealthyReleaseRolloutJob" do
      described_class.new.perform
      expect(AutomaticUpdateRolloutJob).not_to have_received(:perform_async)
    end
  end
end
