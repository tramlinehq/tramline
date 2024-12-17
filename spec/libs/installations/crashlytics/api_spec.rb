require "rails_helper"

Dataset = Struct.new(:dataset_id, :project_id)
APP_IDENTIFIER = "com.example.app"
APP_ONE = "App One"
APP_TWO = "App Two"
APP_VERSION = "1.0.0"

describe Installations::Crashlytics::Api, type: :integration do
  let(:project_number) { Faker::Number.number(digits: 8).to_s }
  let(:json_key) do
    StringIO.new(File.read("spec/fixtures/crashlytics/service_account.json"))
  end
  let(:api_instance) { described_class.new(project_number, json_key) }

  let(:app_id) { APP_IDENTIFIER }
  let(:version) { APP_VERSION }
  let(:build_number) { "100" }
  let(:transforms) { CrashlyticsIntegration::RELEASE_TRANSFORMATIONS }
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

  describe "#find_release" do
    let(:bundle_identifier) { APP_IDENTIFIER }
    let(:api_instance) { described_class.new(project_number, json_key) }
    let(:analytics_query_result) do
      [
        {
          version_name: APP_VERSION,
          sessions: 200,
          daily_users: 150,
          sessions_in_last_day: 100,
          sessions_with_errors: 50,
          total_sessions_in_last_day: 150,
          daily_users_with_errors: 30
        }
      ]
    end
    let(:crashlytics_query_result) do
      [
        {
          version_name: APP_VERSION,
          errors_count: 10,
          new_errors_count: 5,
          external_release_id: "release_123"
        }
      ]
    end

    context "when release data is found" do
      before do
        allow(bigquery_client).to receive(:query).with(instance_of(String)).and_return(analytics_query_result, crashlytics_query_result)
      end

      it "returns the transformed release data" do
        result = api_instance.find_release(app_id, version, build_number, transforms, bundle_identifier)
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
      before do
        allow(bigquery_client).to receive(:query).and_return([])
      end

      it "returns nil" do
        result = api_instance.find_release(app_id, version, build_number, transforms, bundle_identifier)
        expect(result).to be_nil
      end
    end
  end

  describe "#datasets" do
    it "returns a hash with GA4 and Crashlytics datasets" do
      expected = {
        ga4: "#{datasets[0].project_id}.analytics_12345.*",
        crashlytics: "#{datasets[1].project_id}.firebase_crashlytics.*"
      }
      expect(api_instance.send(:datasets)).to eq(expected)
    end
  end
end
