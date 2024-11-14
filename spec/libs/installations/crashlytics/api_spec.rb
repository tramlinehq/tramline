require "rails_helper"

Dataset = Struct.new(:dataset_id, :project_id)

APP_ONE = "App One"
ANDROID_APP = "Android App"
IOS_APP = "iOS App"

describe Installations::Crashlytics::Api, type: :integration do
  let(:project_number) { Faker::Number.number(digits: 8).to_s }
  let(:json_key) { StringIO.new({client_email: "client@test.com", private_key: "private_key"}.to_json) }
  let(:api_instance) { described_class.new(project_number, json_key) }

  let(:app_id) { "com.example.app" }
  let(:version) { "1.0.0" }
  let(:build_number) { "100" }
  let(:payload) do
    {
      new_errors_count: 5,
      errors_count: 10,
      sessions_in_last_day: 100,
      sessions: 200,
      sessions_with_errors: 50,
      daily_users_with_errors: 30,
      daily_users: 150,
      total_sessions_in_last_day: 150,
      external_release_id: "release_123"
    }
  end
  let(:transforms) { CrashlyticsIntegration::RELEASE_TRANSFORMATIONS }

  describe "#find_release" do
    context "when release data is found" do
      it "returns the transformed release data" do
        allow(api_instance).to receive(:fetch_crash_data).with(app_id, version).and_return(payload)

        result = api_instance.find_release(app_id, version, build_number, transforms)
        expected_data = {
          "daily_users" => 150,
          "daily_users_with_errors" => 30,
          "errors_count" => 10,
          "external_release_id" => "release_123",
          "new_errors_count" => 5,
          "sessions" => 200,
          "sessions_in_last_day" => 100,
          "sessions_with_errors" => 50,
          "total_sessions_in_last_day" => 150
        }

        expect(result).to eq(expected_data)
      end
    end

    context "when no release data is found" do
      it "returns nil" do
        allow(api_instance).to receive(:fetch_crash_data).with(app_id, version).and_return(nil)
        expect(api_instance.find_release(app_id, version, build_number, transforms)).to be_nil
      end
    end
  end

  describe "#list_apps" do
    let(:transforms) { {"app_id" => "app_id", "display_name" => "display_name", "platform" => "platform"} }
    let(:mock_apps) {
      [
        {app_id: "app_1", display_name: APP_ONE, platform: "ios"},
        {app_id: "app_2", display_name: ANDROID_APP, platform: "android"}
      ]
    }
    let(:firebase_service) { instance_double(Installations::Google::Firebase::Api) }

    before do
      allow(api_instance).to receive(:firebase_management_service).and_return(firebase_service)
      allow(firebase_service).to receive(:list_apps).with(transforms).and_return(mock_apps)
    end

    context "when apps are successfully listed" do
      it "returns a transformed list of Firebase apps" do
        expect(api_instance.list_apps(transforms)).to eq(mock_apps)
      end
    end

    context "when transformations are incorrect" do
      it "raises an error or returns invalid results when transformations don't match" do
        incorrect_apps = [{wrong_id: "app_1", wrong_name: APP_ONE}]
        allow(firebase_service).to receive(:list_apps).with(transforms).and_return(incorrect_apps)

        expect(api_instance.list_apps(transforms)).not_to eq(mock_apps)
      end

      it "fails when the platform field is missing in transformations" do
        incomplete_mock_apps = [{app_id: "app_1", display_name: APP_ONE}, {app_id: "app_2", display_name: ANDROID_APP}]
        allow(firebase_service).to receive(:list_apps).with(transforms).and_return(incomplete_mock_apps)

        expect(api_instance.list_apps(transforms)).not_to eq(mock_apps)
      end
    end
  end

  describe "#datasets" do
    let(:bigquery_client) { instance_double(Google::Cloud::Bigquery::Project) }
    let(:datasets) do
      [
        Dataset.new("analytics_12345", "project_id"),
        Dataset.new("firebase_crashlytics", "project_id")
      ]
    end

    before do
      allow(api_instance).to receive(:bigquery_client).and_return(bigquery_client)
      allow(bigquery_client).to receive(:datasets).and_return(datasets)
    end

    it "returns a hash with GA4 and Crashlytics datasets" do
      expected = {
        ga4: "#{datasets[0].project_id}.analytics_12345.*",
        crashlytics: "#{datasets[1].project_id}.firebase_crashlytics.*"
      }
      expect(api_instance.send(:datasets)).to eq(expected)
    end
  end

  describe "#fetch_crash_data" do
    let(:app_id) { Faker::Alphanumeric.alphanumeric(number: 8) }
    let(:release_data) { {analytics_data: [{version_name: "1.0.0"}], crashlytics_data: [{version_name: "1.0.0"}]} }

    before do
      allow(api_instance).to receive(:release_data).with(app_id).and_return(release_data)
    end

    context "when data for the version is found" do
      it "merges analytics and crashlytics data for a matching version" do
        expect(api_instance.send(:fetch_crash_data, app_id, "1.0.0")).to eq(version_name: "1.0.0")
      end
    end

    context "when version is not found" do
      it "returns an empty hash" do
        expect(api_instance.send(:fetch_crash_data, app_id, "2.0.0")).to eq({})
      end
    end
  end
end
