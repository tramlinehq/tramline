require "rails_helper"

describe Deployments::GooglePlayStore::Upload, type: :job do
  describe "#perform" do
    let(:slack_deployment_run) { create(:deployment_run, :started, :with_slack) }
    let(:store_deployment_run) { create(:deployment_run, :started, :with_google_play_store) }

    it "does nothing if deployment is not google play store" do
      allow(Installations::Google::PlayDeveloper::Api).to receive(:upload)

      described_class.new.perform(slack_deployment_run.id)

      expect(Installations::Google::PlayDeveloper::Api).not_to have_received(:upload)
    end

    it "uploads the package to store" do
      allow(Installations::Google::PlayDeveloper::Api).to receive(:upload)

      described_class.new.perform(store_deployment_run.id)

      expect(Installations::Google::PlayDeveloper::Api).to have_received(:upload).once
    end

    it "marks deployment runs as uploaded if there are allowed exceptions" do
      allow(Installations::Google::PlayDeveloper::Api).to receive(:upload).and_raise(Installations::Errors::BuildExistsInBuildChannel.new)

      described_class.new.perform(store_deployment_run.id)

      expect(store_deployment_run.reload.uploaded?).to be(true)
    end

    it "marks deployment runs as upload failed if there are disallowed exceptions" do
      allow(Installations::Google::PlayDeveloper::Api).to receive(:upload).and_raise(Installations::Errors::BundleIdentifierNotFound.new)

      described_class.new.perform(store_deployment_run.id)

      expect(store_deployment_run.reload.upload_failed?).to be(true)
    end
  end
end
