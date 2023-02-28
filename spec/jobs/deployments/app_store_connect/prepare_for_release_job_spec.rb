require "rails_helper"

describe Deployments::AppStoreConnect::PrepareForReleaseJob do
  describe "#perform" do
    let(:success_release_info) {
      {
        version_name: "1.6.3",
        app_store_state: "PREPARE_FOR_SUBMISSION"
      }
    }

    it "marks the run as prepared_release" do
      allow_any_instance_of(Installations::Apple::AppStoreConnect::Api).to receive(:prepare_release).and_return(success_release_info)
      run = create_deployment_run_for_ios(:started, deployment_trait: :with_production_channel, step_trait: :release)

      described_class.new.perform(run.id)
      expect(run.reload.prepared_release?).to be(true)
    end

    it "does nothing if not an app store deployment" do
      allow_any_instance_of(Installations::Apple::AppStoreConnect::Api).to receive(:prepare_release).and_return(success_release_info)
      run = create(:deployment_run)

      described_class.new.perform(run.id)
      expect(run.reload.prepared_release?).not_to be(true)
    end
  end
end
