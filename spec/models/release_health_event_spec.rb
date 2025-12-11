require "rails_helper"

RSpec.describe ReleaseHealthEvent do
  describe "callbacks" do
    describe "#trigger_halt_on_unhealthy" do
      let(:production_release) { create(:production_release) }
      let(:release_health_rule) { create(:release_health_rule, :session_stability) }
      let(:release_health_metric) { create(:release_health_metric, production_release:) }

      before do
        allow(HaltUnhealthyReleaseRolloutJob).to receive(:perform_async)
      end

      context "when an unhealthy event is created" do
        it "triggers the halt job" do
          create(:release_health_event, :unhealthy, production_release:, release_health_rule:, release_health_metric:)
          expect(HaltUnhealthyReleaseRolloutJob).to have_received(:perform_async)
        end

        it "passes the production_release_id and event_id to the job" do
          event = create(:release_health_event, :unhealthy, production_release:, release_health_rule:, release_health_metric:)
          expect(HaltUnhealthyReleaseRolloutJob).to have_received(:perform_async).with(production_release.id, event.id)
        end
      end

      context "when a healthy event is created" do
        it "does not trigger the halt job" do
          create(:release_health_event, :healthy, production_release:, release_health_rule:, release_health_metric:)
          expect(HaltUnhealthyReleaseRolloutJob).not_to have_received(:perform_async)
        end
      end
    end
  end
end
