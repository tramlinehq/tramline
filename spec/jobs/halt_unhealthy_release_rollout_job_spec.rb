require "rails_helper"

RSpec.describe HaltUnhealthyReleaseRolloutJob do
  let(:play_store_integration) { instance_double(GooglePlayStoreIntegration) }
  let(:play_store_submission) { create(:play_store_submission, :prod_release) }
  let(:production_release) { play_store_submission.parent_release }
  let(:release_health_event) { create(:release_health_event, :unhealthy, production_release:) }

  before do
    allow_any_instance_of(ReleasePlatformRun).to receive(:store_provider).and_return(play_store_integration)
    allow(play_store_integration).to receive(:halt_release).and_return(GitHub::Result.new { true })
    create(:store_rollout, :play_store, :started, is_staged_rollout: true, automatic_rollout: true, store_submission: play_store_submission, current_stage: 1)
  end

  context "when job is run for a release with automatic staged rollout" do
    context "when release is healthy" do
      before do
        allow_any_instance_of(ProductionRelease).to receive(:healthy?).and_return(true)
      end

      it "does not halt the release" do
        described_class.new.perform(production_release.id, release_health_event.id)
        expect(play_store_integration).not_to have_received(:halt_release)
      end

      it "does not mark the event as action_triggered" do
        expect {
          described_class.new.perform(production_release.id, release_health_event.id)
        }.not_to change { release_health_event.reload.action_triggered }
      end
    end

    context "when release is not healthy" do
      before do
        allow_any_instance_of(ProductionRelease).to receive(:healthy?).and_return(false)
      end

      it "halts the release" do
        described_class.new.perform(production_release.id, release_health_event.id)
        expect(play_store_integration).to have_received(:halt_release)
      end

      it "marks the event as action_triggered" do
        expect {
          described_class.new.perform(production_release.id, release_health_event.id)
        }.to change { release_health_event.reload.action_triggered }.from(false).to(true)
      end
    end
  end

  context "when job is run for release without automatic staged rollout" do
    before do
      production_release.store_rollout.update!(automatic_rollout: false)
    end

    context "when release is healthy" do
      before do
        allow_any_instance_of(ProductionRelease).to receive(:healthy?).and_return(true)
      end

      it "does not halt the release" do
        described_class.new.perform(production_release.id, release_health_event.id)
        expect(play_store_integration).not_to have_received(:halt_release)
      end

      it "does not mark the event as action_triggered" do
        expect {
          described_class.new.perform(production_release.id, release_health_event.id)
        }.not_to change { release_health_event.reload.action_triggered }
      end
    end

    context "when release is not healthy" do
      before do
        allow_any_instance_of(ProductionRelease).to receive(:healthy?).and_return(false)
      end

      it "does not halt the release" do
        described_class.new.perform(production_release.id, release_health_event.id)
        expect(play_store_integration).not_to have_received(:halt_release)
      end

      it "does not mark the event as action_triggered" do
        expect {
          described_class.new.perform(production_release.id, release_health_event.id)
        }.not_to change { release_health_event.reload.action_triggered }
      end
    end
  end
end
