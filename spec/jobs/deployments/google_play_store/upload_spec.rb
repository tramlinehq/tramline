require "rails_helper"

describe Deployments::GooglePlayStore::Upload, type: :job do
  describe "#perform" do
    let(:slack_deployment_run) { create(:deployment_run, :started, :with_slack) }
    let(:store_deployment_run) { create(:deployment_run, :started, :with_google_play_store) }

    it "does nothing if deployment is not google play store" do
      expect_any_instance_of(DeploymentRun).not_to receive(:upload_to_playstore!)
      described_class.new.perform(slack_deployment_run.id)
    end

    it "calls upload to playstore if deployment is google play store" do
      expect_any_instance_of(DeploymentRun).to receive(:upload_to_playstore!).once
      described_class.new.perform(store_deployment_run.id)
    end
  end
end
