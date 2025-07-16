require "rails_helper"

describe Installations::Linear::Api do
  let(:access_token) { "test_access_token" }
  let(:api) { described_class.new(access_token) }

  describe ".get_access_token" do
    let(:code) { "test_code" }
    let(:redirect_uri) { "http://test.com/callback" }

    before do
      creds = OpenStruct.new(
        integrations: OpenStruct.new(
          linear: OpenStruct.new(
            client_id: "test_client_id",
            client_secret: "test_secret"
          )
        )
      )
      allow(described_class).to receive(:creds).and_return(creds)
    end

    it "makes a POST request to Linear's token endpoint" do
      response_body = {
        "access_token" => "new_access_token",
        "refresh_token" => "new_refresh_token"
      }

      stub_request(:post, "https://api.linear.app/oauth/token")
        .to_return(status: 200, body: response_body.to_json)

      result = described_class.get_access_token(code, redirect_uri)

      expect(result.access_token).to eq("new_access_token")
      expect(result.refresh_token).to eq("new_refresh_token")
    end
  end

  describe ".get_organizations" do
    it "fetches organizations using GraphQL" do
      response_body = {
        "data" => {
          "organization" => {"id" => "org_id", "name" => "Test Org"}
        }
      }

      stub_request(:post, "https://api.linear.app/graphql")
        .to_return(status: 200, body: response_body.to_json)

      result = described_class.get_organizations(access_token)

      expect(result).to eq([{"id" => "org_id", "name" => "Test Org"}])
    end
  end

  describe "#teams" do
    let(:transformations) { {id: :id, name: :name} }

    it "fetches teams using GraphQL" do
      response_body = {
        "data" => {
          "teams" => {
            "nodes" => [
              {"id" => "team1", "name" => "Team 1"},
              {"id" => "team2", "name" => "Team 2"}
            ]
          }
        }
      }

      stub_request(:post, "https://api.linear.app/graphql")
        .to_return(status: 200, body: response_body.to_json)

      result = api.teams(transformations)

      expect(result).to eq([
        {"id" => "team1", "name" => "Team 1"},
        {"id" => "team2", "name" => "Team 2"}
      ])
    end
  end

  describe "#workflow_states" do
    let(:transformations) { {id: :id, name: :name, type: :type} }

    it "fetches workflow states using GraphQL" do
      response_body = {
        "data" => {
          "workflowStates" => {
            "nodes" => [
              {"id" => "state1", "name" => "Todo", "type" => "unstarted"},
              {"id" => "state2", "name" => "Done", "type" => "completed"}
            ]
          }
        }
      }

      stub_request(:post, "https://api.linear.app/graphql")
        .to_return(status: 200, body: response_body.to_json)

      result = api.workflow_states(transformations)

      expect(result).to eq([
        {"id" => "state1", "name" => "Todo", "type" => "unstarted"},
        {"id" => "state2", "name" => "Done", "type" => "completed"}
      ])
    end
  end

  describe "#search_issues_by_filters" do
    let(:team_id) { "team1" }
    let(:release_filters) { [{"type" => "label", "value" => "release"}] }
    let(:transformations) { {id: :id, title: :title} }

    it "searches issues using GraphQL with filters" do
      response_body = {
        "data" => {
          "issues" => {
            "nodes" => [
              {"id" => "issue1", "title" => "Test Issue"}
            ]
          }
        }
      }

      stub_request(:post, "https://api.linear.app/graphql")
        .to_return(status: 200, body: response_body.to_json)

      result = api.search_issues_by_filters(team_id, release_filters, transformations)

      expect(result["issues"]).to eq([{"id" => "issue1", "title" => "Test Issue"}])
    end

    it "returns empty issues when filters are blank" do
      result = api.search_issues_by_filters(team_id, [], transformations)
      expect(result["issues"]).to eq([])
    end
  end

  describe "error handling" do
    describe ".get_access_token" do
      let(:code) { "test_code" }
      let(:redirect_uri) { "http://test.com/callback" }

      before do
        creds = OpenStruct.new(
          integrations: OpenStruct.new(
            linear: OpenStruct.new(
              client_id: "test_client_id",
              client_secret: "test_secret"
            )
          )
        )
        allow(described_class).to receive(:creds).and_return(creds)
      end

      it "returns OpenStruct with nil values when server returns 500 error" do
        stub_request(:post, "https://api.linear.app/oauth/token")
          .to_return(status: 500, body: '{"error": "Internal Server Error"}')

        result = described_class.get_access_token(code, redirect_uri)
        expect(result).to be_a(OpenStruct)
        expect(result.access_token).to be_nil
        expect(result.refresh_token).to be_nil
      end

      it "returns OpenStruct with nil values when server returns 4xx error" do
        stub_request(:post, "https://api.linear.app/oauth/token")
          .to_return(status: 400, body: '{"error": "invalid_request"}')

        result = described_class.get_access_token(code, redirect_uri)
        expect(result).to be_a(OpenStruct)
        expect(result.access_token).to be_nil
        expect(result.refresh_token).to be_nil
      end
    end

    describe ".get_organizations" do
      it "returns empty array when server returns 500 error" do
        stub_request(:post, "https://api.linear.app/graphql")
          .to_return(status: 500, body: "Internal Server Error")

        result = described_class.get_organizations(access_token)
        expect(result).to eq([])
      end

      it "returns empty array when HTTP error occurs" do
        stub_request(:post, "https://api.linear.app/graphql")
          .to_raise(HTTP::Error.new("Network error"))

        result = described_class.get_organizations(access_token)
        expect(result).to eq([])
      end
    end

    describe "#execute_graphql" do
      it "raises ServerError when server returns 500" do
        stub_request(:post, "https://api.linear.app/graphql")
          .to_return(status: 500, body: "Internal Server Error")

        expect { api.teams({id: :id}) }.to raise_error(Installations::Error::ServerError)
      end

      it "raises TokenExpired when server returns 401" do
        stub_request(:post, "https://api.linear.app/graphql")
          .to_return(status: 401, body: '{"errors": [{"message": "Unauthorized"}]}')

        expect { api.teams({id: :id}) }.to raise_error(Installations::Error::TokenExpired)
      end

      it "raises ResourceNotFound when server returns 404" do
        stub_request(:post, "https://api.linear.app/graphql")
          .to_return(status: 404, body: '{"errors": [{"message": "Not found"}]}')

        expect { api.teams({id: :id}) }.to raise_error(Installations::Error::ResourceNotFound)
      end

      it "raises Linear::Error for other client errors" do
        stub_request(:post, "https://api.linear.app/graphql")
          .to_return(status: 422, body: '{"errors": [{"message": "Validation failed"}]}')

        expect { api.teams({id: :id}) }.to raise_error(Installations::Linear::Error)
      end
    end
  end
end
