require "rails_helper"

ANDROID_APP = "Android App"
IOS_APP = "iOS App"
APP_ONE = "App One"
FIND_RELEASE_SHARED_EXAMPLE = "find_release with correct arguments"

RSpec.describe CrashlyticsIntegration do
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

  describe "#setup" do
    let(:android_app) { create(:app, :android) }
    let(:ios_app) { create(:app, :ios) }

    before do
      allow(crashlytics_integration).to receive(:list_apps).with(platform: "android").and_return([{app_id: "android_app", display_name: ANDROID_APP}])
      allow(crashlytics_integration).to receive(:list_apps).with(platform: "ios").and_return([{app_id: "ios_app", display_name: IOS_APP}])
    end

    it "returns the apps based on the integrable platform" do
      android_integration = create(:integration, integrable: android_app)
      ios_integration = create(:integration, integrable: ios_app)

      crashlytics_integration.integration = android_integration
      expect(crashlytics_integration.setup).to eq({android: [{app_id: "android_app", display_name: ANDROID_APP}]})

      crashlytics_integration.integration = ios_integration
      expect(crashlytics_integration.setup).to eq({ios: [{app_id: "ios_app", display_name: IOS_APP}]})
    end
  end

  describe "#find_release" do
    let(:version) { "1.0.0" }
    let(:build_number) { "100" }

    before do
      allow(crashlytics_integration.integration.app.config).to receive_messages(
        firebase_ios_config: {"app_id" => "sampleiosappid", "display_name" => IOS_APP},
        firebase_android_config: {"app_id" => "sampleandroidappid", "display_name" => ANDROID_APP}
      )
    end

    shared_examples FIND_RELEASE_SHARED_EXAMPLE do |platform|
      it "calls the API find_release method with correct arguments for #{platform.capitalize} platform" do
        project = crashlytics_integration.project(platform)
        crashlytics_integration.find_release(platform, version, build_number)

        expect(api_instance).to have_received(:find_release).with(project, version, build_number, CrashlyticsIntegration::RELEASE_TRANSFORMATIONS)
      end
    end

    it_behaves_like FIND_RELEASE_SHARED_EXAMPLE, "android"
    it_behaves_like FIND_RELEASE_SHARED_EXAMPLE, "ios"

    it "returns nil if version is blank" do
      expect(crashlytics_integration.find_release("android", nil, build_number)).to be_nil
    end
  end

  describe "#list_apps" do
    let(:apps) { [{platform: "android", app_id: "1", display_name: APP_ONE}, {platform: "ios", app_id: "2", display_name: IOS_APP}] }

    before do
      allow(Rails.cache).to receive(:fetch).and_yield
      allow(api_instance).to receive(:list_apps).and_return(apps)
    end

    it "fetches and caches apps filtered by platform" do
      result = crashlytics_integration.list_apps(platform: "android")
      expect(result).to eq([{app_id: "1", display_name: APP_ONE}])
    end

    it "returns only iOS apps when platform is ios" do
      result = crashlytics_integration.list_apps(platform: "ios")
      expect(result).to eq([{app_id: "2", display_name: IOS_APP}])
    end
  end

  describe "#correct_key" do
    before do
      allow(api_instance).to receive(:list_apps).and_return([{}])
    end

    it "does not add errors" do
      crashlytics_integration.correct_key
      expect(crashlytics_integration.errors).to be_empty
    end
  end

  describe "#connection_data" do
    it "returns the project number in the connection data" do
      expect(crashlytics_integration.connection_data).to eq("Project: #{crashlytics_integration.project_number}")
    end
  end
end
