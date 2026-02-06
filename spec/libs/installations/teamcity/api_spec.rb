require "rails_helper"

describe Installations::Teamcity::Api do
  let(:server_url) { "https://teamcity.example.com" }
  let(:access_token) { "test-token" }
  let(:api) { described_class.new(server_url, access_token) }

  describe "#server_version" do
    it "returns the server version" do
      stub_request(:get, "#{server_url}/app/rest/server")
        .to_return(status: 200, body: {"version" => "2024.12.1"}.to_json, headers: {"Content-Type" => "application/json"})

      expect(api.server_version).to eq("2024.12.1")
    end

    it "raises on server error" do
      stub_request(:get, "#{server_url}/app/rest/server")
        .to_return(status: 500, body: "Internal Server Error")

      expect { api.server_version }.to raise_error(Installations::Error)
    end

    it "returns nil on client error" do
      stub_request(:get, "#{server_url}/app/rest/server")
        .to_return(status: 404, body: {}.to_json, headers: {"Content-Type" => "application/json"})

      expect(api.server_version).to be_nil
    end
  end

  describe "#list_projects" do
    let(:transforms) { TeamcityIntegration::PROJECTS_TRANSFORMATIONS }

    it "returns transformed projects excluding _Root" do
      payload = {
        "project" => [
          {"id" => "_Root", "name" => "Root project"},
          {"id" => "MyProject", "name" => "My Project", "description" => "A project"}
        ]
      }
      stub_request(:get, "#{server_url}/app/rest/projects")
        .to_return(status: 200, body: payload.to_json, headers: {"Content-Type" => "application/json"})

      result = api.list_projects(transforms)
      expect(result.size).to eq(1)
      expect(result.first[:id]).to eq("MyProject")
      expect(result.first[:name]).to eq("My Project")
    end
  end

  describe "#trigger_build" do
    let(:transforms) { TeamcityIntegration::BUILD_RUN_TRANSFORMATIONS }

    it "triggers a build and returns transformed response" do
      payload = {"id" => 123, "number" => "42", "webUrl" => "https://teamcity.example.com/build/123"}
      stub_request(:post, "#{server_url}/app/rest/buildQueue")
        .to_return(status: 200, body: payload.to_json, headers: {"Content-Type" => "application/json"})

      inputs = {build_version: "1.0.0", version_code: 42}
      result = api.trigger_build("MyProject_Build", "main", inputs, "abc123", transforms)

      expect(result[:ci_ref]).to eq("123")
      expect(result[:number]).to eq("42")
    end

    it "raises when response is blank" do
      stub_request(:post, "#{server_url}/app/rest/buildQueue")
        .to_return(status: 404, body: {}.to_json, headers: {"Content-Type" => "application/json"})

      inputs = {build_version: "1.0.0"}
      expect {
        api.trigger_build("MyProject_Build", "main", inputs, nil, transforms)
      }.to raise_error(Installations::Error)
    end
  end

  describe "#cancel_build" do
    it "cancels a queued build via buildQueue endpoint" do
      # First, get_build returns queued state
      stub_request(:get, "#{server_url}/app/rest/builds/id:123")
        .to_return(status: 200, body: {"id" => 123, "state" => "queued"}.to_json, headers: {"Content-Type" => "application/json"})

      stub_request(:post, "#{server_url}/app/rest/buildQueue/id:123")
        .to_return(status: 200, body: {}.to_json, headers: {"Content-Type" => "application/json"})

      api.cancel_build(123)

      expect(WebMock).to have_requested(:post, "#{server_url}/app/rest/buildQueue/id:123")
    end

    it "cancels a running build via builds endpoint" do
      stub_request(:get, "#{server_url}/app/rest/builds/id:123")
        .to_return(status: 200, body: {"id" => 123, "state" => "running"}.to_json, headers: {"Content-Type" => "application/json"})

      stub_request(:post, "#{server_url}/app/rest/builds/id:123")
        .to_return(status: 200, body: {}.to_json, headers: {"Content-Type" => "application/json"})

      api.cancel_build(123)

      expect(WebMock).to have_requested(:post, "#{server_url}/app/rest/builds/id:123")
        .with(body: hash_including("comment" => /Cancelled by Tramline/))
    end
  end

  describe "#find_build" do
    let(:transforms) { TeamcityIntegration::BUILD_RUN_TRANSFORMATIONS }

    it "finds a build by type, branch and commit" do
      payload = {
        "build" => [{"id" => 123, "number" => "42", "webUrl" => "https://teamcity.example.com/build/123"}]
      }
      stub_request(:get, "#{server_url}/app/rest/builds")
        .with(query: hash_including("locator"))
        .to_return(status: 200, body: payload.to_json, headers: {"Content-Type" => "application/json"})

      result = api.find_build("MyProject_Build", "main", "abc123", transforms)
      expect(result[:ci_ref]).to eq("123")
    end

    it "raises when build not found" do
      payload = {"build" => []}
      stub_request(:get, "#{server_url}/app/rest/builds")
        .with(query: hash_including("locator"))
        .to_return(status: 200, body: payload.to_json, headers: {"Content-Type" => "application/json"})

      expect {
        api.find_build("MyProject_Build", "main", "abc123", transforms)
      }.to raise_error(Installations::Error)
    end

    it "encodes branch names with special characters" do
      payload = {"build" => [{"id" => 123, "number" => "42", "webUrl" => "https://teamcity.example.com/build/123"}]}
      stub_request(:get, "#{server_url}/app/rest/builds")
        .with(query: hash_including("locator"))
        .to_return(status: 200, body: payload.to_json, headers: {"Content-Type" => "application/json"})

      api.find_build("MyProject_Build", "release/1.0", "abc123", transforms)

      expect(WebMock).to have_requested(:get, "#{server_url}/app/rest/builds")
        .with(query: hash_including("locator" => /branch:\(name:release\/1\.0\)/))
    end
  end

  describe "#list_artifacts" do
    it "returns only artifact files" do
      payload = {
        "file" => [
          {"name" => "app-release.apk", "size" => 1024},
          {"name" => "build-log.txt", "size" => 512},
          {"name" => "app-release.aab", "size" => 2048}
        ]
      }
      stub_request(:get, "#{server_url}/app/rest/builds/id:123/artifacts")
        .to_return(status: 200, body: payload.to_json, headers: {"Content-Type" => "application/json"})

      result = api.list_artifacts(123)
      expect(result.size).to eq(2)
      expect(result.map { |f| f["name"] }).to contain_exactly("app-release.apk", "app-release.aab")
    end
  end

  describe "cloudflare credentials" do
    let(:cf_creds) { {client_id: "abc.access", client_secret: "secret123"} }
    let(:api_with_cf) { described_class.new(server_url, access_token, cloudflare_credentials: cf_creds) }

    it "includes CF headers when cloudflare is enabled" do
      stub_request(:get, "#{server_url}/app/rest/server")
        .with(headers: {"CF-Access-Client-Id" => "abc.access", "CF-Access-Client-Secret" => "secret123"})
        .to_return(status: 200, body: {"version" => "2024.12.1"}.to_json, headers: {"Content-Type" => "application/json"})

      expect(api_with_cf.server_version).to eq("2024.12.1")
    end
  end

  describe ".filter_by_name" do
    it "filters artifacts by name pattern" do
      artifacts = [
        {name: "app-release.apk", size_in_bytes: 1024},
        {name: "app-debug.apk", size_in_bytes: 512}
      ]
      result = described_class.filter_by_name(artifacts, "release")
      expect(result.size).to eq(1)
      expect(result.first[:name]).to eq("app-release.apk")
    end

    it "returns all artifacts when no pattern" do
      artifacts = [{name: "app.apk", size_in_bytes: 1024}]
      expect(described_class.filter_by_name(artifacts, nil)).to eq(artifacts)
    end

    it "falls back to all artifacts when no match" do
      artifacts = [{name: "app.apk", size_in_bytes: 1024}]
      expect(described_class.filter_by_name(artifacts, "nonexistent")).to eq(artifacts)
    end
  end

  describe ".find_biggest" do
    it "returns the largest artifact" do
      artifacts = [
        {name: "small.apk", size_in_bytes: 100},
        {name: "large.apk", size_in_bytes: 5000},
        {name: "medium.apk", size_in_bytes: 1000}
      ]
      expect(described_class.find_biggest(artifacts)[:name]).to eq("large.apk")
    end
  end
end
