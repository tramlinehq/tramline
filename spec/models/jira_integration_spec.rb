require "rails_helper"

RSpec.describe JiraIntegration do
  subject(:integration) { build(:jira_integration) }

  let(:sample_release_label) { "release-1.0" }
  let(:sample_version) { "v1.0.0" }

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
      let(:error) { Installations::Jira::Error.new("error" => {"message" => "The access token expired"}) }
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
      app.config.update!(jira_config: {
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
        app.config.update!(jira_config: {
          "release_filters" => [{"type" => "label", "value" => sample_release_label}]
        })
        expect(integration.fetch_tickets_for_release).to eq([])
      end

      it "returns empty array when no release filters" do
        app.config.update!(jira_config: {
          "selected_projects" => ["PROJ"]
        })
        expect(integration.fetch_tickets_for_release).to eq([])
      end
    end
  end

  describe "#validate_release_filters" do
    let(:app) { create(:app, :android) }
    let(:integration) { build(:jira_integration, integration: create(:integration, integrable: app)) }

    context "with invalid filter type" do
      let(:filters) { [{"type" => "invalid", "value" => "test"}] }

      before do
        app.config.update!(jira_config: {"release_filters" => filters})
        integration.valid?
      end

      it "is invalid" do
        expect(integration).not_to be_valid
        expect(integration.errors[:release_filters]).to include("must contain valid type and value")
      end
    end

    context "with empty filter value" do
      let(:filters) { [{"type" => "label", "value" => ""}] }

      before do
        app.config.update!(jira_config: {"release_filters" => filters})
        integration.valid?
      end

      it "is invalid" do
        expect(integration).not_to be_valid
        expect(integration.errors[:release_filters]).to include("must contain valid type and value")
      end
    end

    context "with valid filters" do
      let(:filters) do
        [
          {"type" => "label", "value" => sample_release_label},
          {"type" => "fix_version", "value" => sample_version}
        ]
      end

      before do
        app.config.update!(jira_config: {"release_filters" => filters})
        integration.valid?
      end

      it "is valid" do
        expect(integration).to be_valid
      end
    end
  end
end
