require "rails_helper"
require "webmock/rspec"

describe Installations::Jira::Api do
  let(:oauth_access_token) { "test_token" }
  let(:cloud_id) { "test_cloud_id" }
  let(:api) { described_class.new(oauth_access_token, cloud_id) }
  let(:transformations) { JiraIntegration::TICKET_TRANSFORMATIONS }

  describe ".get_accessible_resources" do
    let(:code) { "test_code" }
    let(:redirect_uri) { "http://example.com/callback" }

    context "when successful" do
      let(:resources) { [{"id" => "cloud_1"}] }
      let(:tokens) { {"access_token" => "token", "refresh_token" => "refresh"} }

      before do
        allow(described_class).to receive(:creds)
          .and_return(OpenStruct.new(
            integrations: OpenStruct.new(
              jira: OpenStruct.new(
                client_id: "test_id",
                client_secret: "test_secret"
              )
            )
          ))

        stub_request(:post, "https://auth.atlassian.com/oauth/token")
          .with(
            body: {
              grant_type: "authorization_code",
              code: code,
              redirect_uri: redirect_uri
            }
          )
          .to_return(body: tokens.to_json)

        stub_request(:get, "https://api.atlassian.com/oauth/token/accessible-resources")
          .with(headers: {"Authorization" => "Bearer #{tokens["access_token"]}"})
          .to_return(body: resources.to_json, status: 200)
      end

      it "returns resources and tokens" do
        result_resources, result_tokens = described_class.get_accessible_resources(code, redirect_uri)
        expect(result_resources).to eq(resources)
        expect(result_tokens.access_token).to eq(tokens["access_token"])
      end
    end

    context "when HTTP error occurs" do
      before do
        allow(described_class).to receive(:creds)
          .and_return(OpenStruct.new(
            integrations: OpenStruct.new(
              jira: OpenStruct.new(
                client_id: "test_id",
                client_secret: "test_secret"
              )
            )
          ))

        stub_request(:post, "https://auth.atlassian.com/oauth/token")
          .with(
            basic_auth: ["test_id", "test_secret"],
            body: {
              grant_type: "authorization_code",
              code: code,
              redirect_uri: redirect_uri
            }
          )
          .to_return(body: tokens.to_json)

        stub_request(:get, "https://api.atlassian.com/oauth/token/accessible-resources")
          .to_raise(HTTP::Error.new("Network error"))
      end

      let(:tokens) { {"access_token" => "token", "refresh_token" => "refresh"} }

      it "returns empty resources with tokens" do
        resources, tokens = described_class.get_accessible_resources(code, redirect_uri)
        expect(resources).to be_empty
        expect(tokens).to be_present
      end
    end
  end

  describe "#search_tickets_by_filters" do
    let(:project_key) { "TEST" }
    let(:empty_response) { {"issues" => []} }

    context "when release filters are not configured" do
      it "returns empty issues array" do
        result = api.search_tickets_by_filters(project_key, [], transformations)
        expect(result["issues"]).to eq([])
      end
    end

    context "with release filters" do
      let(:release_filters) do
        [
          {"type" => "label", "value" => "release-1.0"},
          {"type" => "fix_version", "value" => "1.0.0"}
        ]
      end

      let(:mock_response) do
        {
          "issues" => [
            {
              "key" => "TEST-1",
              "fields" => {
                "summary" => "Test issue",
                "status" => {"name" => "Done"},
                "assignee" => {"displayName" => "John Doe"},
                "labels" => ["release-1.0."],
                "fixVersions" => [{"name" => "1.0.0"}]
              }
            }
          ]
        }
      end

      it "returns original response structure" do
        allow(api).to receive(:execute).and_return(mock_response)
        result = api.search_tickets_by_filters(project_key, release_filters, transformations)
        expect(result[0]["key"]).to eq(mock_response["issues"][0]["key"])
      end

      it "builds correct JQL query" do
        expected_query = "project = 'TEST' AND labels = 'release-1.0' AND fixVersion = '1.0.0'"
        expected_url = "https://api.atlassian.com/ex/jira/#{cloud_id}/rest/api/3/search/jql"
        expected_params = {
          params: {
            jql: expected_query,
            fields: described_class::TICKET_SEARCH_FIELDS
          }
        }

        allow(api).to receive(:execute).and_return({"issues" => []})

        api.search_tickets_by_filters(project_key, release_filters, transformations)

        expect(api).to have_received(:execute)
          .with(:get, expected_url, expected_params)
      end
    end
  end

  describe "#execute" do
    context "when handling errors" do
      let(:url) { "https://api.atlassian.com/ex/jira/#{cloud_id}/rest/api/3/test" }

      it "raises ServerError when server returns 500" do
        stub_request(:get, url)
          .with(headers: {"Authorization" => "Bearer #{oauth_access_token}"})
          .to_return(status: 500, body: "Internal Server Error")

        expect { api.send(:execute, :get, url) }.to raise_error(Installations::Error::ServerError)
      end

      it "raises TokenExpired when server returns 401" do
        stub_request(:get, url)
          .with(headers: {"Authorization" => "Bearer #{oauth_access_token}"})
          .to_return(status: 401, body: '{"error": {"message": "Unauthorized"}}')

        expect { api.send(:execute, :get, url) }.to raise_error(Installations::Error::TokenExpired)
      end

      it "raises ResourceNotFound when server returns 404" do
        stub_request(:get, url)
          .with(headers: {"Authorization" => "Bearer #{oauth_access_token}"})
          .to_return(status: 404, body: '{"error": {"message": "Not found"}}')

        expect { api.send(:execute, :get, url) }.to raise_error(Installations::Error::ResourceNotFound)
      end

      it "raises Jira::Error for other client errors" do
        stub_request(:get, url)
          .with(headers: {"Authorization" => "Bearer #{oauth_access_token}"})
          .to_return(status: 422, body: '{"error": {"message": "Validation failed"}}')

        expect { api.send(:execute, :get, url) }.to raise_error(Installations::Jira::Error)
      end

      it "returns parsed response for successful requests" do
        response_body = {data: "test"}
        stub_request(:get, url)
          .with(headers: {"Authorization" => "Bearer #{oauth_access_token}"})
          .to_return(status: 200, body: response_body.to_json)

        result = api.send(:execute, :get, url)
        expect(result).to eq({"data" => "test"})
      end
    end
  end
end
