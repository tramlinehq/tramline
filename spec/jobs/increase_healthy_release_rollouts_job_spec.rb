# frozen_string_literal: true

require "rails_helper"

RSpec.describe IncreaseHealthyReleaseRolloutsJob do
  let(:play_store_integration) { instance_double(GooglePlayStoreIntegration) }
  let(:play_store_submission) { create(:play_store_submission, :prod_release) }

  before do
    allow_any_instance_of(ReleasePlatformRun).to receive(:store_provider).and_return(play_store_integration)
    allow(play_store_integration).to receive(:rollout_release).and_return(GitHub::Result.new { true })
  end

  context "when a play store rollout (staged) is available for rollout for the first time" do
    let!(:store_rollout) { create(:store_rollout, :play_store, :created, is_staged_rollout: true, automatic_rollout: true, store_submission: play_store_submission) }

    it "rolls out the release" do
      described_class.new.perform
      expect(play_store_integration).to have_received(:rollout_release)
      expect(store_rollout.reload.current_stage).to eq(0)
    end
  end

  context "when a play store rollout (staged) is rolled out in first stage" do
    let!(:store_rollout) { create(:store_rollout, :play_store, :started, is_staged_rollout: true, automatic_rollout: true, store_submission: play_store_submission, current_stage: 1) }

    context "when release is healthy" do
      before do
        allow_any_instance_of(ProductionRelease).to receive(:healthy?).and_return(true)
      end

      it "rolls out the release to next stage" do
        described_class.new.perform
        expect(play_store_integration).to have_received(:rollout_release)
        expect(store_rollout.reload.current_stage).to eq(2)
      end
    end

    context "when release is unhealthy" do
      before do
        allow_any_instance_of(ProductionRelease).to receive(:healthy?).and_return(false)
      end

      it "does not roll out the release to next stage" do
        described_class.new.perform
        expect(play_store_integration).not_to have_received(:rollout_release)
        expect(store_rollout.reload.current_stage).to eq(1)
      end
    end
  end

  context "when a play store rollout (staged) is halted" do
    before do
      create(:store_rollout, :play_store, :halted, is_staged_rollout: true, automatic_rollout: true, store_submission: play_store_submission)
    end

    it "does not rollout the release" do
      described_class.new.perform
      expect(play_store_integration).not_to have_received(:rollout_release)
    end
  end

  context "when a play store rollout (staged) is completed" do
    before do
      create(:store_rollout, :play_store, :completed, is_staged_rollout: true, automatic_rollout: true, store_submission: play_store_submission)
    end

    it "does not rollout the release" do
      described_class.new.perform
      expect(play_store_integration).not_to have_received(:rollout_release)
    end
  end

  context "when a play store submission (non-staged) is available for rollout" do
    before do
      create(:store_rollout, :play_store, :created, is_staged_rollout: false, store_submission: play_store_submission)
    end

    it "does not rollout the release" do
      described_class.new.perform
      expect(play_store_integration).not_to have_received(:rollout_release)
    end
  end
end
