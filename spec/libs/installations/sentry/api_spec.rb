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
        .with(headers: {"Authorization" => "Bearer #{access_token}"})
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

    let(:expected_projects_with_org) do
      [
        {"name" => "iOS App", "id" => "1", "slug" => "ios-app", "platform" => "apple-ios", "organization_slug" => org_slug},
        {"name" => "Android App", "id" => "2", "slug" => "android-app", "platform" => "android", "organization_slug" => org_slug}
      ]
    end

    before do
      stub_request(:get, "#{base_url}/organizations/#{org_slug}/projects/")
        .with(headers: {"Authorization" => "Bearer #{access_token}"})
        .to_return(status: 200, body: projects_response.to_json, headers: {"Content-Type" => "application/json"})
    end

    it "makes a GET request to the projects endpoint" do
      api_instance.list_projects(org_slug, transforms)

      expect(WebMock).to have_requested(:get, "#{base_url}/organizations/#{org_slug}/projects/")
        .with(headers: {"Authorization" => "Bearer #{access_token}"})
    end

    it "returns the transformed projects list with organization slug" do
      result = api_instance.list_projects(org_slug, transforms)

      expect(result).to be_an(Array)
      expect(result.first).to include("name" => "iOS App", "id" => "1", "slug" => "ios-app", "organization_slug" => org_slug)
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

    context "with pagination" do
      let(:projects_page1) { [{"id" => "1", "slug" => "proj-1", "name" => "Project 1", "platform" => "python"}] }
      let(:projects_page2) { [{"id" => "2", "slug" => "proj-2", "name" => "Project 2", "platform" => "javascript"}] }

      before do
        # First page with Link header
        stub_request(:get, "#{base_url}/organizations/#{org_slug}/projects/")
          .with(headers: {"Authorization" => "Bearer #{access_token}"})
          .to_return(
            status: 200,
            body: projects_page1.to_json,
            headers: {
              "Content-Type" => "application/json",
              "Link" => "<https://sentry.io/api/0/organizations/#{org_slug}/projects/?cursor=xyz789>; rel=\"next\""
            }
          )

        # Second page without Link header (last page)
        stub_request(:get, "#{base_url}/organizations/#{org_slug}/projects/")
          .with(query: {"cursor" => "xyz789"}, headers: {"Authorization" => "Bearer #{access_token}"})
          .to_return(
            status: 200,
            body: projects_page2.to_json,
            headers: {"Content-Type" => "application/json"}
          )
      end

      it "fetches all pages and attaches organization_slug to each project" do
        result = api_instance.list_projects(org_slug, transforms)

        expect(result).to be_an(Array)
        expect(result.length).to eq(2)
        expect(result.first[:organization_slug]).to eq(org_slug)
        expect(result.last[:organization_slug]).to eq(org_slug)
      end

      it "makes requests for both pages" do
        api_instance.list_projects(org_slug, transforms)

        # Verify first page request (without cursor)
        expect(WebMock).to have_requested(:get, "#{base_url}/organizations/#{org_slug}/projects/")
          .with(headers: {"Authorization" => "Bearer #{access_token}"})
        # Verify second page request (with cursor)
        expect(WebMock).to have_requested(:get, "#{base_url}/organizations/#{org_slug}/projects/")
          .with(query: {"cursor" => "xyz789"})
      end
    end
  end

  describe "#list_organizations with pagination" do
    let(:transforms) { SentryIntegration::ORGANIZATIONS_TRANSFORMATIONS }
    let(:orgs_page1) { [{"id" => "1", "slug" => "org-1", "name" => "Org 1"}] }
    let(:orgs_page2) { [{"id" => "2", "slug" => "org-2", "name" => "Org 2"}] }

    before do
      # First page with Link header
      stub_request(:get, "#{base_url}/organizations/")
        .with(headers: {"Authorization" => "Bearer #{access_token}"})
        .to_return(
          status: 200,
          body: orgs_page1.to_json,
          headers: {
            "Content-Type" => "application/json",
            "Link" => '<https://sentry.io/api/0/organizations/?cursor=abc123>; rel="next"'
          }
        )

      # Second page without Link header (last page)
      stub_request(:get, "#{base_url}/organizations/")
        .with(query: {"cursor" => "abc123"}, headers: {"Authorization" => "Bearer #{access_token}"})
        .to_return(
          status: 200,
          body: orgs_page2.to_json,
          headers: {"Content-Type" => "application/json"}
        )
    end

    it "fetches all pages and concatenates results" do
      result = api_instance.list_organizations(transforms)

      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
      expect(result.map { |o| o[:slug] }).to contain_exactly("org-1", "org-2")
    end

    it "makes requests for both pages" do
      api_instance.list_organizations(transforms)

      # Verify first page request (without cursor)
      expect(WebMock).to have_requested(:get, "#{base_url}/organizations/")
        .with(headers: {"Authorization" => "Bearer #{access_token}"})
      # Verify second page request (with cursor)
      expect(WebMock).to have_requested(:get, "#{base_url}/organizations/")
        .with(query: {"cursor" => "abc123"})
    end
  end

  describe "#paginated_execute" do
    context "with max_results limit" do
      it "stops when max_results is reached" do
        # First page with 10 items
        stub_request(:get, "#{base_url}/test/")
          .with(headers: {"Authorization" => "Bearer #{access_token}"})
          .to_return(
            status: 200,
            body: Array.new(10) { |i| {"id" => i} }.to_json,
            headers: {"Link" => '<https://sentry.io/api/0/test/?cursor=abc>; rel="next"'}
          )

        # Second page would have more
        stub_request(:get, "#{base_url}/test/")
          .with(query: {"cursor" => "abc"}, headers: {"Authorization" => "Bearer #{access_token}"})
          .to_return(
            status: 200,
            body: Array.new(10) { |i| {"id" => i + 10} }.to_json,
            headers: {"Link" => '<https://sentry.io/api/0/test/?cursor=xyz>; rel="next"'}
          )

        result = api_instance.send(:paginated_execute, "/test/", max_results: 15)

        # Should fetch both pages but stop at 20 items (first full page that exceeds 15)
        expect(result.length).to eq(20)
        # Verify both pages were requested
        expect(WebMock).to have_requested(:get, "#{base_url}/test/")
          .with(headers: {"Authorization" => "Bearer #{access_token}"})
        expect(WebMock).to have_requested(:get, "#{base_url}/test/")
          .with(query: {"cursor" => "abc"})
      end
    end
  end

  describe "#find_release" do
    let(:org_slug) { "test-org" }
    let(:project_id) { "123" }
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
    let(:all_issues_response) do
      [
        {"id" => "1", "title" => "Issue 1", "count" => "100"},
        {"id" => "2", "title" => "Issue 2", "count" => "50"},
        {"id" => "3", "title" => "Issue 3", "count" => "25"}
      ]
    end
    let(:new_issues_response) do
      [
        {"id" => "2", "title" => "Issue 2", "count" => "50"},
        {"id" => "3", "title" => "Issue 3", "count" => "25"}
      ]
    end

    before do
      # Stub get_request_async to return a Thread with the stubbed response
      # This avoids the complexity of HTTP stubbing across threads
      allow(api_instance).to receive(:get_request_async).and_call_original

      # Sessions endpoint
      allow(api_instance).to receive(:get_request_async)
        .with("/organizations/#{org_slug}/sessions/", hash_including(project: project_id))
        .and_return(Thread.new { sessions_response })

      # All issues endpoint
      allow(api_instance).to receive(:get_request_async)
        .with("/projects/#{org_slug}/#{project_slug}/issues/", {query: "release:#{version_string}"})
        .and_return(Thread.new { all_issues_response })

      # New issues endpoint
      allow(api_instance).to receive(:get_request_async)
        .with("/projects/#{org_slug}/#{project_slug}/issues/", {query: "firstRelease:#{version_string}"})
        .and_return(Thread.new { new_issues_response })
    end

    it "constructs the correct Sentry release identifier" do
      api_instance.find_release(org_slug, project_id, project_slug, environment, bundle_identifier, app_version, app_version_code, transforms)

      # Verify the sessions API was called with a query containing the version string
      expect(api_instance).to have_received(:get_request_async)
        .with("/organizations/#{org_slug}/sessions/", hash_including(query: "release:#{version_string}"))
    end

    it "makes a GET request to the sessions endpoint with correct parameters" do
      api_instance.find_release(org_slug, project_id, project_slug, environment, bundle_identifier, app_version, app_version_code, transforms)

      # Verify sessions endpoint was called with at least project_id
      expect(api_instance).to have_received(:get_request_async)
        .with("/organizations/#{org_slug}/sessions/", hash_including(project: project_id))
    end

    it "returns the transformed release data with correct structure" do
      result = api_instance.find_release(org_slug, project_id, project_slug, environment, bundle_identifier, app_version, app_version_code, transforms)

      expect(result).to be_a(Hash)
      expect(result["external_release_id"]).to eq(version_string)
      expect(result["sessions"]).to eq(10000) # 9500 + 400 + 100
      expect(result["daily_users"]).to eq(1000) # 800 + 150 + 50
    end

    it "includes session error counts in release data" do
      result = api_instance.find_release(org_slug, project_id, project_slug, environment, bundle_identifier, app_version, app_version_code, transforms)

      expect(result["sessions_with_errors"]).to eq(500) # 400 errored + 100 crashed
      expect(result["daily_users_with_errors"]).to eq(200) # 150 + 50
    end

    it "includes issue counts in release data" do
      result = api_instance.find_release(org_slug, project_id, project_slug, environment, bundle_identifier, app_version, app_version_code, transforms)

      expect(result["errors_count"]).to eq(3) # All issues in release
      expect(result["new_errors_count"]).to eq(2) # Issues first seen in release
    end

    it "fetches issue counts from the issues API" do
      api_instance.find_release(org_slug, project_id, project_slug, environment, bundle_identifier, app_version, app_version_code, transforms)

      # Verify all issues endpoint was called
      expect(api_instance).to have_received(:get_request_async)
        .with("/projects/#{org_slug}/#{project_slug}/issues/", {query: "release:#{version_string}"})

      # Verify new issues endpoint was called
      expect(api_instance).to have_received(:get_request_async)
        .with("/projects/#{org_slug}/#{project_slug}/issues/", {query: "firstRelease:#{version_string}"})
    end

    context "when the API returns an error" do
      before do
        # Override the sessions stub to return nil (simulating error)
        allow(api_instance).to receive(:get_request_async)
          .with("/organizations/#{org_slug}/sessions/", hash_including(project: project_id))
          .and_return(Thread.new { nil })
      end

      it "returns nil" do
        expect(api_instance.find_release(org_slug, project_id, project_slug, environment, bundle_identifier, app_version, app_version_code, transforms)).to be_nil
      end
    end

    context "when no session data is found" do
      before do
        # Override the sessions stub to return empty groups
        allow(api_instance).to receive(:get_request_async)
          .with("/organizations/#{org_slug}/sessions/", hash_including(project: project_id))
          .and_return(Thread.new { {"groups" => []} })
      end

      it "returns nil when sessions data is empty" do
        expect(api_instance.find_release(org_slug, project_id, project_slug, environment, bundle_identifier, app_version, app_version_code, transforms)).to be_nil
      end
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
    let(:issues_data) { {new_issues_count: 5, total_issues_count: 10} }

    it "calculates total sessions correctly" do
      result = api_instance.send(:build_release_data, stats, version_string, issues_data)
      expect(result[:total_sessions_count]).to eq(1000)
    end

    it "calculates total users correctly" do
      result = api_instance.send(:build_release_data, stats, version_string, issues_data)
      expect(result[:total_users_count]).to eq(120)
    end

    it "calculates errored sessions including crashed sessions" do
      result = api_instance.send(:build_release_data, stats, version_string, issues_data)
      expect(result[:errored_sessions_count]).to eq(100) # 80 errored + 20 crashed
    end

    it "calculates users with errors correctly" do
      result = api_instance.send(:build_release_data, stats, version_string, issues_data)
      expect(result[:users_with_errors_count]).to eq(20) # 15 + 5
    end

    it "includes issue counts from issues_data" do
      result = api_instance.send(:build_release_data, stats, version_string, issues_data)
      expect(result[:new_issues_count]).to eq(5)
      expect(result[:total_issues_count]).to eq(10)
    end

    it "defaults to zero when issues_data is not provided" do
      result = api_instance.send(:build_release_data, stats, version_string)
      expect(result[:new_issues_count]).to eq(0)
      expect(result[:total_issues_count]).to eq(0)
    end

    it "sets the version string as the external release ID" do
      result = api_instance.send(:build_release_data, stats, version_string, issues_data)
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
