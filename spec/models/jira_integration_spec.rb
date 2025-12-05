require "rails_helper"

describe JiraIntegration do
  subject(:integration) { build(:jira_integration) }

  let(:sample_release_label) { "release-1.0" }
  let(:sample_version) { "v1.0.0" }

  describe "validations" do
    describe "release filters" do
      context "with invalid filter type" do
        it "is invalid" do
          integration.project_config = {
            "release_filters" => [{"type" => "invalid", "value" => "test"}]
          }
          expect(integration).not_to be_valid
          expect(integration.errors[:project_config]).to include("release filters must contain valid type and value")
        end
      end

      context "with empty filter value" do
        it "is invalid" do
          integration.project_config = {
            "release_filters" => [{"type" => "label", "value" => ""}]
          }
          expect(integration).not_to be_valid
          expect(integration.errors[:project_config]).to include("release filters must contain valid type and value")
        end
      end

      context "with valid filters" do
        it "is valid" do
          integration.project_config = {
            "release_filters" => [
              {"type" => "label", "value" => sample_release_label},
              {"type" => "fix_version", "value" => sample_version}
            ]
          }
          expect(integration).to be_valid
        end
      end
    end
  end

  describe "#installation" do
    it "returns a new API instance with correct credentials" do
      api = integration.installation
      expect(api).to be_a(Installations::Jira::Api)
      expect(api.oauth_access_token).to eq(integration.oauth_access_token)
      expect(api.cloud_id).to eq(integration.cloud_id)
    end
  end

  describe "#with_api_retries" do
    context "when token expired" do
      let(:error) { Installations::Error::TokenExpired }
      let(:integration) { build(:jira_integration) }

      it "retries after refreshing token" do
        call_count = 0
        allow(integration).to receive(:reset_tokens!)

        result = integration.send(:with_api_retries) do
          call_count += 1
          raise error if call_count == 1
          "success"
        end

        expect(integration).to have_received(:reset_tokens!).once
        expect(result).to eq("success")
      end
    end

    context "when max retries exceeded" do
      it "raises the error" do
        expect do
          integration.send(:with_api_retries) { raise Installations::Jira::Error.new({}) }
        end.to raise_error(Installations::Jira::Error)
      end
    end
  end

  describe "#fetch_tickets_for_release" do
    let(:app) { create(:app, :android) }
    let(:integration) { create(:jira_integration, integration: create(:integration, integrable: app)) }
    let(:api_response) do
      {
        "issues" => [
          {
            "key" => "PROJ-1",
            "fields" => {
              "summary" => "Test ticket",
              "status" => {"name" => "Done"},
              "assignee" => {"displayName" => "John Doe"},
              "labels" => [sample_release_label],
              "fixVersions" => [{"name" => sample_version}]
            }
          }
        ]
      }
    end

    before do
      integration.update!(project_config: {
        "selected_projects" => ["PROJ"],
        "release_filters" => [{"type" => "label", "value" => sample_release_label}]
      })

      allow_any_instance_of(Installations::Jira::Api)
        .to receive(:search_tickets_by_filters)
        .with("PROJ", [{"type" => "label", "value" => sample_release_label}], any_args)
        .and_return(api_response)
    end

    it "returns formatted tickets" do
      expect(integration.fetch_tickets_for_release).to eq([{"key" => "PROJ-1",
                                                            "fields" =>
                                                               {"summary" => "Test ticket",
                                                                "status" => {"name" => "Done"},
                                                                "assignee" => {"displayName" => "John Doe"},
                                                                "labels" => [sample_release_label],
                                                                "fixVersions" => [{"name" => sample_version}]}}])
    end

    context "when missing required configuration" do
      it "returns empty array when no selected projects" do
        integration.update!(project_config: {
          "release_filters" => [{"type" => "label", "value" => sample_release_label}]
        })
        expect(integration.fetch_tickets_for_release).to eq([])
      end

      it "returns empty array when no release filters" do
        integration.update!(project_config: {
          "selected_projects" => ["PROJ"]
        })
        expect(integration.fetch_tickets_for_release).to eq([])
      end
    end
  end

  describe "#complete_access" do
    let(:integration) { build(:jira_integration, cloud_id: nil) }
    let(:code) { "test_auth_code" }
    let(:redirect_uri) { "http://localhost:3000/auth/jira/callback" }

    before do
      integration.code = code
      allow(integration).to receive(:redirect_uri).and_return(redirect_uri)
    end

    context "when code or redirect_uri is blank" do
      it "returns false when code is blank" do
        integration.code = ""
        result = integration.complete_access
        expect(result).to be(false)
      end

      it "returns false when redirect_uri is blank" do
        allow(integration).to receive(:redirect_uri).and_return("")
        result = integration.complete_access
        expect(result).to be(false)
      end
    end

    context "when cloud_id is already set" do
      let(:existing_cloud_id) { "existing_cloud_123" }
      let(:integration) { build(:jira_integration, cloud_id: existing_cloud_id) }
      let(:resources) do
        [
          {
            "id" => existing_cloud_id,
            "url" => "https://existing.atlassian.net",
            "name" => "Existing Organization"
          },
          {
            "id" => "other_cloud_456",
            "url" => "https://other.atlassian.net",
            "name" => "Other Organization"
          }
        ]
      end
      let(:tokens) { OpenStruct.new(access_token: "new_token", refresh_token: "new_refresh") }

      before do
        allow(JiraIntegration::API).to receive(:get_accessible_resources)
          .with(code, redirect_uri)
          .and_return([resources, tokens])
      end

      it "returns true and updates organization metadata when matching resource found" do
        result = integration.complete_access

        expect(result).to be(true)
        expect(integration.organization_url).to eq("https://existing.atlassian.net")
        expect(integration.organization_name).to eq("Existing Organization")
        expect(integration.oauth_access_token).to eq("new_token")
        expect(integration.oauth_refresh_token).to eq("new_refresh")
      end

      it "returns false when no matching resource found" do
        allow(JiraIntegration::API).to receive(:get_accessible_resources)
          .with(code, redirect_uri)
          .and_return([[{"id" => "different_cloud", "url" => "https://different.atlassian.net", "name" => "Different Org"}], tokens])

        result = integration.complete_access
        expect(result).to be_falsey
      end
    end

    context "when cloud_id is not set and single resource available" do
      let(:single_resource) do
        {
          "id" => "cloud_123",
          "url" => "https://testorg.atlassian.net",
          "name" => "Test Organization"
        }
      end
      let(:tokens) { OpenStruct.new(access_token: "access_token", refresh_token: "refresh_token") }

      before do
        allow(JiraIntegration::API).to receive(:get_accessible_resources)
          .with(code, redirect_uri)
          .and_return([[single_resource], tokens])
      end

      it "returns true and sets cloud_id with organization metadata" do
        result = integration.complete_access

        expect(result).to be(true)
        expect(integration.cloud_id).to eq("cloud_123")
        expect(integration.organization_url).to eq("https://testorg.atlassian.net")
        expect(integration.organization_name).to eq("Test Organization")
        expect(integration.oauth_access_token).to eq("access_token")
        expect(integration.oauth_refresh_token).to eq("refresh_token")
      end
    end

    context "when cloud_id is not set and multiple resources available" do
      let(:multiple_resources) do
        [
          {
            "id" => "cloud_123",
            "url" => "https://org1.atlassian.net",
            "name" => "Organization 1"
          },
          {
            "id" => "cloud_456",
            "url" => "https://org2.atlassian.net",
            "name" => "Organization 2"
          }
        ]
      end
      let(:tokens) { OpenStruct.new(access_token: "access_token", refresh_token: "refresh_token") }

      before do
        allow(JiraIntegration::API).to receive(:get_accessible_resources)
          .with(code, redirect_uri)
          .and_return([multiple_resources, tokens])
      end

      it "returns false and sets available_resources for user selection" do
        result = integration.complete_access

        expect(result).to be(false)
        expect(integration.cloud_id).to be_nil
        expect(integration.available_resources).to eq(multiple_resources)
        expect(integration.oauth_access_token).to eq("access_token")
        expect(integration.oauth_refresh_token).to eq("refresh_token")
      end
    end

    context "when no resources available" do
      let(:tokens) { OpenStruct.new(access_token: "access_token", refresh_token: "refresh_token") }

      before do
        allow(JiraIntegration::API).to receive(:get_accessible_resources)
          .with(code, redirect_uri)
          .and_return([[], tokens])
      end

      it "returns false and sets tokens but no cloud_id" do
        result = integration.complete_access

        expect(result).to be(false)
        expect(integration.cloud_id).to be_nil
        expect(integration.available_resources).to eq([])
        expect(integration.oauth_access_token).to eq("access_token")
        expect(integration.oauth_refresh_token).to eq("refresh_token")
      end
    end
  end
end
