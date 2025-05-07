require "rails_helper"

RSpec.describe HaltUnhealthyReleaseRolloutJob do
  let(:play_store_integration) { instance_double(GooglePlayStoreIntegration) }
  let(:play_store_submission) { create(:play_store_submission, :prod_release) }

  before do
    allow_any_instance_of(ReleasePlatformRun).to receive(:store_provider).and_return(play_store_integration)
    allow(play_store_integration).to receive(:halt_release).and_return(GitHub::Result.new { true })
  end

  context "when job is run for a release with automatic staged rollout" do
    let(:store_rollout) { create(:store_rollout, :play_store, :started, is_staged_rollout: true, automatic_rollout: true, store_submission: play_store_submission, current_stage: 1) }

    context "when release is healthy" do
      before do
        allow_any_instance_of(ProductionRelease).to receive(:healthy?).and_return(true)
      end

      it "does not halt the release" do
        described_class.new.perform(store_rollout.parent_release.id)
        expect(play_store_integration).not_to have_received(:halt_release)
      end
    end

    context "when release is not healthy" do
      before do
        allow_any_instance_of(ProductionRelease).to receive(:healthy?).and_return(false)
      end

      it "halts the release" do
        described_class.new.perform(store_rollout.parent_release.id)
        expect(play_store_integration).to have_received(:halt_release)
      end
    end
  end

  context "when job is run for release without automatic staged rollout" do
    let(:store_rollout) { create(:store_rollout, :play_store, :started, is_staged_rollout: true, automatic_rollout: false, store_submission: play_store_submission, current_stage: 1) }

    context "when release is healthy" do
      before do
        allow_any_instance_of(ProductionRelease).to receive(:healthy?).and_return(true)
      end

      it "does not halt the release" do
        described_class.new.perform(store_rollout.parent_release.id)
        expect(play_store_integration).not_to have_received(:halt_release)
      end
    end

    context "when release is not healthy" do
      before do
        allow_any_instance_of(ProductionRelease).to receive(:healthy?).and_return(false)
      end

      it "does not halt the release" do
        described_class.new.perform(store_rollout.parent_release.id)
        expect(play_store_integration).not_to have_received(:halt_release)
      end
    end
  end
end
