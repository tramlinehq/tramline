require "rails_helper"

describe Deployments::GooglePlayStore::Upload do
  describe "#perform" do
    it "does nothing if deployment is not google play store" do
      slack_deployment_run = create(:deployment_run, :started, :with_slack)
      allow(Deployments::GooglePlayStore::Release).to receive(:upload!)
      described_class.new.perform(slack_deployment_run.id)
      expect(Deployments::GooglePlayStore::Release).not_to have_received(:upload!)
    end

    it "calls upload to playstore if deployment is google play store" do
      store_deployment_run = create_deployment_run_tree(:android, :started)[:deployment_run]
      allow(Deployments::GooglePlayStore::Release).to receive(:upload!)
      described_class.new.perform(store_deployment_run.id)
      expect(Deployments::GooglePlayStore::Release).to have_received(:upload!).with(store_deployment_run).once
    end
  end
end
