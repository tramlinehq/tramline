require "rails_helper"

describe Deployments::GooglePlayStore::Upload do
  describe "#perform" do
    let(:slack_deployment_run) { create(:deployment_run, :started, :with_slack) }
    let(:store_deployment_run) { create(:deployment_run, :started, :with_google_play_store) }

    it "does nothing if deployment is not google play store" do
      allow(Deployments::GooglePlayStore::Release).to receive(:upload!)
      described_class.new.perform(slack_deployment_run.id)
      expect(Deployments::GooglePlayStore::Release).not_to have_received(:upload!)
    end

    it "calls upload to playstore if deployment is google play store" do
      allow(Deployments::GooglePlayStore::Release).to receive(:upload!)
      described_class.new.perform(store_deployment_run.id)
      expect(Deployments::GooglePlayStore::Release).to have_received(:upload!).with(store_deployment_run).once
    end
  end
end
