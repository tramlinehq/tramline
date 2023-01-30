require "rails_helper"

describe Deployments::AppStoreConnect::TestFlightPromoteJob do
  describe "#perform" do
    context "when non app store deployment" do
      let(:play_store_deployment_run) { create(:deployment_run, :started, :with_google_play_store) }

      it "does nothing if deployment is not for app store" do
        described_class.new.perform(play_store_deployment_run.id)

        expect(play_store_deployment_run.reload.started?).to be(true)
      end
    end

    context "when app store deployment" do
      let(:app_store_deployment_run) { create(:deployment_run, :started, :with_app_store) }

      before do
        app_store_deployment_run.app.update(platform: "ios")
      end

      it "does nothing if the train run is no longer on track" do
        app_store_deployment_run.release.update(status: "finished")

        described_class.new.perform(app_store_deployment_run.id)

        expect(app_store_deployment_run.reload.started?).to be(true)
      end

      it "creates external build for the deployment run" do
        allow_any_instance_of(Installations::Apple::AppStoreConnect::Api).to receive(:add_build_to_group)

        described_class.new.perform(app_store_deployment_run.id)

        expect(app_store_deployment_run.reload.submitted?).to be(true)
      end
    end
  end
end
