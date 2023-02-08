require "rails_helper"

describe GooglePlayStoreIntegration do
  it "has a valid factory" do
    expect(create(:google_play_store_integration, :without_callbacks_and_validations)).to be_valid
  end

  describe "#upload" do
    let(:integration) { create(:integration, :with_google_play_store) }
    let(:google_integration) { integration.providable }
    let(:file) { Tempfile.new("test_artifact.aab") }
    let(:api_double) { instance_double(Installations::Google::PlayDeveloper::Api) }

    before do
      allow(google_integration).to receive(:installation).and_return(api_double)
    end

    it "uploads file to play store and returns a result object" do
      allow(api_double).to receive(:upload)

      expect(google_integration.upload(file).ok?).to be true
      expect(api_double).to have_received(:upload).with(file).once
    end

    it "returns successful result if there are allowed exceptions" do
      allow(api_double).to receive(:upload).and_raise(Installations::Errors::BuildExistsInBuildChannel.new)

      expect(google_integration.upload(file).ok?).to be true
      expect(api_double).to have_received(:upload).with(file).once
    end

    it "returns failed result if there are disallowed exceptions" do
      allow(api_double).to receive(:upload).and_raise(Installations::Errors::BundleIdentifierNotFound.new)

      expect(google_integration.upload(file).ok?).to be false
      expect(api_double).to have_received(:upload).with(file).once
    end

    it "returns failed result if there are unexpected exceptions" do
      allow(api_double).to receive(:upload).and_raise(StandardError.new)

      expect(google_integration.upload(file).ok?).to be false
      expect(api_double).to have_received(:upload).with(file).once
    end
  end
end
