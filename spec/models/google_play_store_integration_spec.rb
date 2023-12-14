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
      expect(api_double).to have_received(:upload).with(file, skip_review: nil).once
    end

    it "returns successful result if there are allowed exceptions" do
      error_body = {"error" => {"status" => "PERMISSION_DENIED", "code" => 403, "message" => "APK specifies a version code that has already been used"}}
      error = ::Google::Apis::ClientError.new("Error", body: error_body.to_json)
      allow(api_double).to receive(:upload).and_raise(Installations::Google::PlayDeveloper::Error.new(error))

      expect(google_integration.upload(file).ok?).to be true
      expect(api_double).to have_received(:upload).with(file, skip_review: nil).once
    end

    it "retries if there are retryable exceptions" do
      error_body = {"error" => {"status" => "INVALID_ARGUMENT",
                                "code" => 400,
                                "message" => "Changes cannot be sent for review automatically. Please set the query parameter changesNotSentForReview to true. Once committed, the changes in this edit can be sent for review from the Google Play Console UI"}}
      error = Google::Apis::ClientError.new("Error", body: error_body.to_json)
      allow(api_double).to receive(:upload).and_raise(Installations::Google::PlayDeveloper::Error.new(error))

      expect(google_integration.upload(file).ok?).to be false
      expect(api_double).to have_received(:upload).with(file, skip_review: nil).once
      expect(api_double).to have_received(:upload).with(file, skip_review: true).twice
    end

    it "returns failed result if there are disallowed exceptions" do
      error_body = {"error" => {"status" => "NOT_FOUND", "code" => 404, "message" => "Package not found:"}}
      error = ::Google::Apis::ClientError.new("Error", body: error_body.to_json)
      allow(api_double).to receive(:upload).and_raise(Installations::Google::PlayDeveloper::Error.new(error))

      expect(google_integration.upload(file).ok?).to be false
      expect(api_double).to have_received(:upload).with(file, skip_review: nil).once
    end

    it "returns failed result if there are unexpected exceptions" do
      allow(api_double).to receive(:upload).and_raise(StandardError.new)

      expect(google_integration.upload(file).ok?).to be false
      expect(api_double).to have_received(:upload).with(file, skip_review: nil).once
    end
  end
end
