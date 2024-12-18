require "rails_helper"

FIND_RELEASE_DESCRIPTION = "find_release with correct arguments".freeze
ANDROID_APP_NAME = "Android App".freeze
IOS_APP_NAME = "iOS App".freeze
ANDROID_APP_ID = "android_app".freeze
IOS_APP_ID = "ios_app".freeze

describe CrashlyticsIntegration do
  let(:crashlytics_integration) { create(:crashlytics_integration) }
  let(:api_instance) { instance_spy(Installations::Crashlytics::Api) }

  before do
    allow(Installations::Crashlytics::Api).to receive(:new).and_return(api_instance)
    allow_any_instance_of(described_class).to receive(:correct_key).and_return(true)
  end

  it "has a valid factory" do
    expect(crashlytics_integration).to be_valid
  end

  describe "#access_key" do
    it "returns the JSON key as a StringIO object" do
      expect(crashlytics_integration.access_key).to be_a(StringIO)
      expect(crashlytics_integration.access_key.string).to eq(crashlytics_integration.json_key)
    end
  end

  describe "#installation" do
    it "returns an API instance with the project number and JSON key" do
      expect(crashlytics_integration.installation).to eq(api_instance)
    end
  end

  describe "#find_release" do
    let(:version) { "1.0.0" }
    let(:build_number) { "100" }
    let(:bundle_identifier) { "com.example.app" }
    let(:platform) { "ios" }

    before do
      allow(api_instance).to receive(:find_release)
      allow(crashlytics_integration.integrable).to receive(:bundle_identifier).and_return(bundle_identifier)
    end

    it "calls the API find_release method with correct arguments" do
      crashlytics_integration.find_release(platform, version, build_number)

      expect(api_instance).to have_received(:find_release).with(
        bundle_identifier,
        platform,
        version,
        build_number,
        CrashlyticsIntegration::RELEASE_TRANSFORMATIONS
      )
    end

    it "returns nil if version is blank" do
      expect(crashlytics_integration.find_release("android", nil, build_number)).to be_nil
    end
  end

  describe "#connection_data" do
    it "returns the project number in the connection data" do
      expect(crashlytics_integration.connection_data).to eq("Project: #{crashlytics_integration.project_number}")
    end
  end
end
