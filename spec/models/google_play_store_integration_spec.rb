require "rails_helper"

describe GooglePlayStoreIntegration do
  it "has a valid factory" do
    expect(create(:google_play_store_integration, :without_callbacks_and_validations)).to be_valid
  end

  describe "#upload" do
    let(:app) { create(:app, platform: :android) }
    let(:integration) { create(:integration, :with_google_play_store, integrable: app) }
    let(:google_integration) { integration.providable }
    let(:file) { Tempfile.new("test_artifact.aab") }
    let(:api_double) { instance_double(Installations::Google::PlayDeveloper::Api) }

    before do
      allow(google_integration).to receive(:installation).and_return(api_double)
    end

    it "uploads file to play store and returns a result object" do
      allow(api_double).to receive(:upload)

      expect(google_integration.upload(file).ok?).to be true
      expect(api_double).to have_received(:upload).with(file, skip_review: false).once
    end

    it "returns successful result if there are allowed exceptions" do
      error_body = {"error" => {"status" => "PERMISSION_DENIED", "code" => 403, "message" => "APK specifies a version code that has already been used"}}
      error = ::Google::Apis::ClientError.new("Error", body: error_body.to_json)
      allow(api_double).to receive(:upload).and_raise(Installations::Google::PlayDeveloper::Error.new(error))

      expect(google_integration.upload(file).ok?).to be true
      expect(api_double).to have_received(:upload).with(file, skip_review: false).once
    end

    it "retries if there are retryable exceptions" do
      error_body = {"error" => {"status" => "FAILED_PRECONDITION", "code" => 400, "message" => "This Edit has been deleted"}}
      error = Google::Apis::ClientError.new("Error", body: error_body.to_json)
      allow(api_double).to receive(:upload).and_raise(Installations::Google::PlayDeveloper::Error.new(error))

      expect(google_integration.upload(file).ok?).to be false
      expect(api_double).to have_received(:upload).with(file, skip_review: false).exactly(4).times
    end

    it "returns failed result if there are disallowed exceptions" do
      error_body = {"error" => {"status" => "NOT_FOUND", "code" => 404, "message" => "Package not found:"}}
      error = ::Google::Apis::ClientError.new("Error", body: error_body.to_json)
      allow(api_double).to receive(:upload).and_raise(Installations::Google::PlayDeveloper::Error.new(error))

      expect(google_integration.upload(file).ok?).to be false
      expect(api_double).to have_received(:upload).with(file, skip_review: false).once
    end

    it "returns failed result if there are unexpected exceptions" do
      allow(api_double).to receive(:upload).and_raise(StandardError.new)

      expect(google_integration.upload(file).ok?).to be false
      expect(api_double).to have_received(:upload).with(file, skip_review: false).once
    end

    it "retry (with skip review) on review fail" do
      allow(api_double).to receive(:upload).and_raise(play_store_review_error)

      expect(google_integration.upload(file).ok?).to be false
      expect(api_double).to have_received(:upload).with(file, skip_review: false).once
      expect(api_double).to have_received(:upload).with(file, skip_review: true).exactly(3).times
    end
  end

  describe "#create_draft_release" do
    let(:app) { create(:app, platform: :android) }
    let(:integration) { create(:integration, :with_google_play_store, integrable: app) }
    let(:google_integration) { integration.providable }
    let(:file) { Tempfile.new("test_artifact.aab") }
    let(:api_double) { instance_double(Installations::Google::PlayDeveloper::Api) }

    before do
      allow(google_integration).to receive(:installation).and_return(api_double)
    end

    it "retry (with skip review) on review fail when retry is true" do
      allow(api_double).to receive(:create_draft_release).and_raise(play_store_review_error)

      expect(google_integration.create_draft_release("track", 1, "1.0.0", "notes", retry_on_review_fail: true).ok?).to be false
      expect(api_double).to have_received(:create_draft_release).with("track", 1, "1.0.0", "notes", skip_review: false).once
      expect(api_double).to have_received(:create_draft_release).with("track", 1, "1.0.0", "notes", skip_review: true).exactly(3).times
    end

    it "does not retry (with skip review) on review fail when retry is false" do
      allow(api_double).to receive(:create_draft_release).and_raise(play_store_review_error)

      expect(google_integration.create_draft_release("track", 1, "1.0.0", "notes", retry_on_review_fail: false).ok?).to be false
      expect(api_double).to have_received(:create_draft_release).with("track", 1, "1.0.0", "notes", skip_review: false).once
    end
  end

  describe "#rollout_release" do
    let(:app) { create(:app, platform: :android) }
    let(:integration) { create(:integration, :with_google_play_store, integrable: app) }
    let(:google_integration) { integration.providable }
    let(:file) { Tempfile.new("test_artifact.aab") }
    let(:api_double) { instance_double(Installations::Google::PlayDeveloper::Api) }

    before do
      allow(google_integration).to receive(:installation).and_return(api_double)
    end

    it "retry (with skip review) on review fail when retry is true" do
      allow(api_double).to receive(:create_release).and_raise(play_store_review_error)

      expect(google_integration.rollout_release("track", 1, "1.0.0", 0.01, "notes", retry_on_review_fail: true).ok?).to be false
      expect(api_double).to have_received(:create_release).with("track", 1, "1.0.0", 0.01, "notes", skip_review: false).once
      expect(api_double).to have_received(:create_release).with("track", 1, "1.0.0", 0.01, "notes", skip_review: true).exactly(3).times
    end

    it "does not retry (with skip review) on review fail when retry is false" do
      allow(api_double).to receive(:create_release).and_raise(play_store_review_error)

      expect(google_integration.rollout_release("track", 1, "1.0.0", 0.01, "notes", retry_on_review_fail: false).ok?).to be false
      expect(api_double).to have_received(:create_release).with("track", 1, "1.0.0", 0.01, "notes", skip_review: false).once
    end
  end

  describe "#halt_release" do
    let(:app) { create(:app, platform: :android) }
    let(:integration) { create(:integration, :with_google_play_store, integrable: app) }
    let(:google_integration) { integration.providable }
    let(:file) { Tempfile.new("test_artifact.aab") }
    let(:api_double) { instance_double(Installations::Google::PlayDeveloper::Api) }

    before do
      allow(google_integration).to receive(:installation).and_return(api_double)
    end

    it "retry (with skip review) on review fail when retry is true" do
      allow(api_double).to receive(:halt_release).and_raise(play_store_review_error)

      expect(google_integration.halt_release("track", 1, "1.0.0", 0.01, retry_on_review_fail: true).ok?).to be false
      expect(api_double).to have_received(:halt_release).with("track", 1, "1.0.0", 0.01, skip_review: false).once
      expect(api_double).to have_received(:halt_release).with("track", 1, "1.0.0", 0.01, skip_review: true).exactly(3).times
    end

    it "does not retry (with skip review) on review fail when retry is false" do
      allow(api_double).to receive(:halt_release).and_raise(play_store_review_error)

      expect(google_integration.halt_release("track", 1, "1.0.0", 0.01, retry_on_review_fail: false).ok?).to be false
      expect(api_double).to have_received(:halt_release).with("track", 1, "1.0.0", 0.01, skip_review: false).once
    end
  end

  describe "#build_in_progress?" do
    let(:app) { create(:app, platform: :android) }
    let(:integration) { create(:integration, :with_google_play_store, integrable: app) }
    let(:google_integration) { integration.providable }
    let(:file) { Tempfile.new("test_artifact.aab") }
    let(:api_double) { instance_double(Installations::Google::PlayDeveloper::Api) }
    let(:in_progress_track_data) {
      {
        name: :track,
        releases: [
          {
            localizations: [{release_notes: {language: "en-US", text: "text"}}],
            version_string: "1.0.0",
            status: "inProgress",
            user_fraction: 0.99,
            build_number: "1"
          }
        ]
      }
    }
    let(:completed_track_data) {
      {
        name: :track,
        releases: [
          {
            localizations: [{release_notes: {language: "en-US", text: "text"}}],
            version_string: "1.0.0",
            status: "completed",
            user_fraction: 1.0,
            build_number: "1"
          }
        ]
      }
    }

    before do
      allow(google_integration).to receive(:installation).and_return(api_double)
    end

    it "returns true when the release is in progress" do
      allow(api_double).to receive(:get_track).and_return(in_progress_track_data)
      expect(google_integration.build_in_progress?("track", 1)).to be true
    end

    it "returns false when the release is not in progress" do
      allow(api_double).to receive(:get_track).and_return(completed_track_data)
      expect(google_integration.build_in_progress?("track", 1)).to be false
    end
  end
end
