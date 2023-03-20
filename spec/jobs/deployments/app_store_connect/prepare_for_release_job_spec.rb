require "rails_helper"

describe Deployments::AppStoreConnect::PrepareForReleaseJob do
  describe "#perform" do
    it "marks the run as prepared_release" do
      run = create_deployment_run_for_ios(:started, deployment_traits: [:with_production_channel], step_trait: :release)
      success_release_info = {
        external_id: "31aafef2-d5fb-45d4-9b02-f0ab5911c1b2",
        status: "PREPARE_FOR_SUBMISSION",
        build_number: run.build_number,
        name: run.release_version,
        added_at: "2023-02-25T03:02:46-08:00"
      }
      allow_any_instance_of(Installations::Apple::AppStoreConnect::Api).to receive(:prepare_release).and_return(success_release_info)

      described_class.new.perform(run.id)
      expect(run.reload.prepared_release?).to be(true)
    end

    it "does nothing if not an app store deployment" do
      allow_any_instance_of(Installations::Apple::AppStoreConnect::Api).to receive(:prepare_release)
      run = create(:deployment_run)

      described_class.new.perform(run.id)
      expect(run.reload.prepared_release?).not_to be(true)
    end
  end
end
