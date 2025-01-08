require "rails_helper"

RSpec.describe IntegrationListeners::JiraController do
  let(:organization) { create(:organization) }
  let(:app) { create(:app, :android, organization: organization) }
  let(:user) { create(:user, :with_email_authentication, :as_developer, member_organization: organization) }
  let(:state) {
    {
      app_id: app.id,
      user_id: user.id,
      organization_id: organization.id
    }.to_json.encode
  }
  let(:code) { "test_code" }
  let(:integration) { build(:integration, :jira, integrable: app) }
  let(:jira_integration) { build(:jira_integration) }

  before do
    sign_in user.email_authentication
    allow_any_instance_of(described_class).to receive(:current_user).and_return(user)
    allow_any_instance_of(described_class).to receive(:state_user).and_return(user)
    allow_any_instance_of(described_class).to receive(:state_app).and_return(app)
    allow_any_instance_of(described_class).to receive(:state_organization).and_return(organization)
    allow_any_instance_of(described_class).to receive(:build_providable).and_return(jira_integration)
    allow_any_instance_of(described_class).to receive(:valid_state?).and_return(true)
  end

  describe "GET #callback" do
    context "with valid state" do
      context "when single organization" do
        before do
          allow(app.integrations).to receive(:build).and_return(integration)
          allow(integration).to receive_messages(
            providable: jira_integration,
            save!: true,
            valid?: true
          )

          allow(jira_integration).to receive_messages(
            complete_access: true,
            setup: {}
          )

          get :callback, params: {state: state, code: code}
        end

        it "creates integration and redirects to app" do
          expect(response).to redirect_to(app_path(app))
          expect(flash[:alert]).to be_nil
          expect(flash[:notice]).to eq("Integration was successfully created.")
        end
      end

      context "when multiple organizations" do
        let(:resources) { [{"id" => "cloud_1"}, {"id" => "cloud_2"}] }

        before do
          allow(app.integrations).to receive(:build).and_return(integration)
          allow(integration).to receive_messages(
            providable: jira_integration,
            valid?: true
          )

          allow(jira_integration).to receive_messages(
            complete_access: false,
            available_resources: resources
          )

          get :callback, params: {state: state, code: code}
        end

        it "shows organization selection page" do
          expect(response).to be_successful
          expect(response.content_type).to include("text/html")
          expect(flash[:alert]).to be_nil
          expect(jira_integration).to have_received(:available_resources)
        end
      end
    end

    context "with invalid state" do
      before do
        allow_any_instance_of(described_class).to receive(:valid_state?).and_return(false)
        get :callback, params: {state: state, code: code}
      end

      it "redirects with error" do
        expect(response).to redirect_to(app_path(app))
        expect(flash[:alert]).to eq("Failed to create the integration, please try again.")
      end
    end
  end

  describe "POST #set_organization" do
    let(:cloud_id) { "cloud_123" }
    let(:valid_params) do
      {
        cloud_id: cloud_id,
        code: code,
        state: state
      }
    end

    context "with valid parameters" do
      before do
        allow(app.integrations).to receive(:build).and_return(integration)
        allow(integration).to receive_messages(
          providable: jira_integration,
          save!: true
        )

        allow(jira_integration).to receive_messages(
          setup: {}
        )

        post :set_organization, params: valid_params
      end

      it "creates integration and redirects to app integrations" do
        expect(flash[:notice]).to eq("Integration was successfully created.")
      end
    end

    context "with invalid parameters" do
      before do
        allow(app.integrations).to receive(:build).and_return(integration)
        allow(integration).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(integration))

        post :set_organization, params: valid_params
      end

      it "redirects to integrations path with error" do
        expect(response).to redirect_to(app_integrations_path(app))
        expect(flash[:alert]).to eq("Failed to create the integration, please try again.")
      end
    end
  end
end
