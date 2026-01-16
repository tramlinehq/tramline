require "rails_helper"

describe Installations::Sentry::Api do
  let(:access_token) { "sntrys_test_token_1234567890abcdef" }
  let(:api_instance) { described_class.new(access_token) }
  let(:base_url) { "https://sentry.io/api/0" }

  describe "#initialize" do
    it "sets the access token" do
      expect(api_instance.access_token).to eq(access_token)
    end

    it "sets the base URL" do
      expect(api_instance.base_url).to eq(base_url)
    end
  end

  describe "#list_organizations" do
    let(:transforms) { SentryIntegration::ORGANIZATIONS_TRANSFORMATIONS }
    let(:organizations_response) do
      [
        {"name" => "Test Org", "id" => "123", "slug" => "test-org"},
        {"name" => "Another Org", "id" => "456", "slug" => "another-org"}
      ]
    end

    before do
      stub_request(:get, "#{base_url}/organizations/")
        .with(headers: {"Authorization" => "Bearer #{access_token}", "Content-Type" => "application/json"})
        .to_return(status: 200, body: organizations_response.to_json, headers: {"Content-Type" => "application/json"})
    end

    it "makes a GET request to the organizations endpoint" do
      api_instance.list_organizations(transforms)

      expect(WebMock).to have_requested(:get, "#{base_url}/organizations/")
        .with(headers: {"Authorization" => "Bearer #{access_token}"})
    end

    it "returns the transformed organizations list" do
      result = api_instance.list_organizations(transforms)

      expect(result).to be_an(Array)
      expect(result.first).to include("name" => "Test Org", "id" => "123", "slug" => "test-org")
    end

    context "when the API returns an error" do
      before do
        stub_request(:get, "#{base_url}/organizations/")
          .to_return(status: 401, body: {detail: "Unauthorized"}.to_json)
      end

      it "returns nil" do
        expect(api_instance.list_organizations(transforms)).to be_nil
      end
    end
  end

  describe "#list_projects" do
    let(:org_slug) { "test-org" }
    let(:transforms) { SentryIntegration::PROJECTS_TRANSFORMATIONS }
    let(:projects_response) do
      [
        {"name" => "iOS App", "id" => "1", "slug" => "ios-app", "platform" => "apple-ios"},
        {"name" => "Android App", "id" => "2", "slug" => "android-app", "platform" => "android"}
      ]
    end

    before do
      stub_request(:get, "#{base_url}/organizations/#{org_slug}/projects/")
        .with(headers: {"Authorization" => "Bearer #{access_token}", "Content-Type" => "application/json"})
        .to_return(status: 200, body: projects_response.to_json, headers: {"Content-Type" => "application/json"})
    end

    it "makes a GET request to the projects endpoint" do
      api_instance.list_projects(org_slug, transforms)

      expect(WebMock).to have_requested(:get, "#{base_url}/organizations/#{org_slug}/projects/")
        .with(headers: {"Authorization" => "Bearer #{access_token}"})
    end

    it "returns the transformed projects list" do
      result = api_instance.list_projects(org_slug, transforms)

      expect(result).to be_an(Array)
      expect(result.first).to include("name" => "iOS App", "id" => "1", "slug" => "ios-app")
    end

    context "when the API returns an error" do
      before do
        stub_request(:get, "#{base_url}/organizations/#{org_slug}/projects/")
          .to_return(status: 404, body: {detail: "Not Found"}.to_json)
      end

      it "returns nil" do
        expect(api_instance.list_projects(org_slug, transforms)).to be_nil
      end
    end
  end

  describe "#find_release" do
    let(:org_slug) { "test-org" }
    let(:project_slug) { "test-project" }
    let(:environment) { "production" }
    let(:bundle_identifier) { "com.example.app" }
    let(:app_version) { "1.0.0" }
    let(:app_version_code) { "100" }
    let(:transforms) { SentryIntegration::RELEASE_TRANSFORMATIONS }
    let(:version_string) { "#{bundle_identifier}@#{app_version}+#{app_version_code}" }
    let(:sessions_response) do
      {
        "start" => "2024-01-01T00:00:00Z",
        "end" => "2024-01-07T23:59:59Z",
        "intervals" => ["2024-01-01T00:00:00Z", "2024-01-02T00:00:00Z"],
        "groups" => [
          {
            "by" => {"release" => version_string, "session.status" => "healthy"},
            "totals" => {"sum(session)" => 9500, "count_unique(user)" => 800},
            "series" => {"sum(session)" => [5000, 4500]}
          },
          {
            "by" => {"release" => version_string, "session.status" => "errored"},
            "totals" => {"sum(session)" => 400, "count_unique(user)" => 150},
            "series" => {"sum(session)" => [200, 200]}
          },
          {
            "by" => {"release" => version_string, "session.status" => "crashed"},
            "totals" => {"sum(session)" => 100, "count_unique(user)" => 50},
            "series" => {"sum(session)" => [50, 50]}
          }
        ]
      }
    end

    before do
      # Stub the sessions API call with query parameters
      stub_request(:get, "#{base_url}/organizations/#{org_slug}/sessions/")
        .with(
          query: hash_including(
            "project" => project_slug,
            "environment" => environment,
            "query" => "release:#{version_string}"
          ),
          headers: {"Authorization" => "Bearer #{access_token}", "Content-Type" => "application/json"}
        )
        .to_return(status: 200, body: sessions_response.to_json, headers: {"Content-Type" => "application/json"})
    end

    it "constructs the correct Sentry release identifier" do
      api_instance.find_release(org_slug, project_slug, environment, bundle_identifier, app_version, app_version_code, transforms)

      expect(WebMock).to have_requested(:get, "#{base_url}/organizations/#{org_slug}/sessions/")
        .with(query: hash_including("query" => "release:#{bundle_identifier}@#{app_version}+#{app_version_code}"))
    end

    it "makes a GET request to the sessions endpoint with correct parameters" do
      api_instance.find_release(org_slug, project_slug, environment, bundle_identifier, app_version, app_version_code, transforms)

      expect(WebMock).to have_requested(:get, "#{base_url}/organizations/#{org_slug}/sessions/")
        .with(
          query: hash_including(
            "project" => project_slug,
            "environment" => environment,
            "field" => ["sum(session)", "count_unique(user)", "crash_free_rate(session)", "crash_free_rate(user)"],
            "groupBy" => ["release", "session.status"]
          )
        )
    end

    it "returns the transformed release data" do
      result = api_instance.find_release(org_slug, project_slug, environment, bundle_identifier, app_version, app_version_code, transforms)

      expect(result).to be_a(Hash)
      expect(result["external_release_id"]).to eq(version_string)
      expect(result["total_sessions_count"]).to eq(10000) # 9500 + 400 + 100
      expect(result["total_users_count"]).to eq(1000) # 800 + 150 + 50
      expect(result["errored_sessions_count"]).to eq(500) # 400 errored + 100 crashed
      expect(result["users_with_errors_count"]).to eq(200) # 150 + 50
    end

    context "when the API returns an error" do
      before do
        stub_request(:get, "#{base_url}/organizations/#{org_slug}/sessions/")
          .to_return(status: 500, body: {detail: "Internal Server Error"}.to_json)
      end

      it "returns nil" do
        expect(api_instance.find_release(org_slug, project_slug, environment, bundle_identifier, app_version, app_version_code, transforms)).to be_nil
      end
    end

    context "when no session data is found" do
      before do
        stub_request(:get, "#{base_url}/organizations/#{org_slug}/sessions/")
          .to_return(status: 200, body: {"groups" => []}.to_json)
      end

      it "returns nil" do
        expect(api_instance.find_release(org_slug, project_slug, environment, bundle_identifier, app_version, app_version_code, transforms)).to be_nil
      end
    end
  end

  describe "#flatten_params" do
    it "flattens array parameters correctly" do
      params = {field: ["a", "b"], single: "value"}
      result = api_instance.send(:flatten_params, params)

      expect(result).to contain_exactly(
        ["field", "a"],
        ["field", "b"],
        ["single", "value"]
      )
    end
  end

  describe "#build_release_data" do
    let(:version_string) { "com.example.app@1.0.0+100" }
    let(:stats) do
      {
        "groups" => [
          {
            "by" => {"session.status" => "healthy"},
            "totals" => {"sum(session)" => 900, "count_unique(user)" => 100}
          },
          {
            "by" => {"session.status" => "errored"},
            "totals" => {"sum(session)" => 80, "count_unique(user)" => 15}
          },
          {
            "by" => {"session.status" => "crashed"},
            "totals" => {"sum(session)" => 20, "count_unique(user)" => 5}
          }
        ]
      }
    end

    it "calculates total sessions correctly" do
      result = api_instance.send(:build_release_data, stats, version_string)
      expect(result[:total_sessions_count]).to eq(1000)
    end

    it "calculates total users correctly" do
      result = api_instance.send(:build_release_data, stats, version_string)
      expect(result[:total_users_count]).to eq(120)
    end

    it "calculates errored sessions including crashed sessions" do
      result = api_instance.send(:build_release_data, stats, version_string)
      expect(result[:errored_sessions_count]).to eq(100) # 80 errored + 20 crashed
    end

    it "calculates users with errors correctly" do
      result = api_instance.send(:build_release_data, stats, version_string)
      expect(result[:users_with_errors_count]).to eq(20) # 15 + 5
    end

    it "sets the version string as the external release ID" do
      result = api_instance.send(:build_release_data, stats, version_string)
      expect(result[:version]).to eq(version_string)
    end

    context "when there are no sessions" do
      let(:stats) { {"groups" => []} }

      it "returns zero counts" do
        result = api_instance.send(:build_release_data, stats, version_string)

        expect(result[:total_sessions_count]).to eq(0)
        expect(result[:total_users_count]).to eq(0)
        expect(result[:errored_sessions_count]).to eq(0)
        expect(result[:users_with_errors_count]).to eq(0)
      end
    end
  end
end
