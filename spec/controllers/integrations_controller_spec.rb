require "rails_helper"

describe IntegrationsController do
  let(:app) { create(:app, platform: :android) }
  let(:organization) { app.organization }
  let(:user) { create(:user, :with_email_authentication, :as_developer, member_organization: organization) }
  let(:existing_integration) { create(:integration, status: "connected", category: "version_control", providable: create(:github_integration), integrable: app, metadata: {id: Faker::Number.number(digits: 8)}) }

  before do
    sign_in user.email_authentication
    allow_any_instance_of(described_class).to receive(:current_user).and_return(user)
  end

  describe "POST #reuse" do
    context "when the existing integration is not connected or does not exist" do
      it "redirects to the integrations path with an error message" do
        existing_integration.update(status: "disconnected")
        post :reuse, params: {integration: {existing_integration_id: existing_integration.id}, app_id: app.id}

        expect(response).to redirect_to(app_integrations_path(app))
        expect(flash[:alert]).to eq("Integration not found or not connected.")
      end
    end

    context "when the existing integration is connected" do
      it "reuses the integration and redirects to the integrations path with a success message" do
        new_integration = build(:integration, category: "ci_cd", providable: create(:github_integration), integrable: app)

        post :reuse, params: {
          integration: {
            existing_integration_id: existing_integration.id,
            category: new_integration.category,
            providable: {type: new_integration.providable_type}
          }, app_id: app.id
        }

        expect(response).to redirect_to(app_integrations_path(app))
        expect(flash[:notice]).to eq("#{existing_integration.providable_type} integration reused successfully.")
      end

      it "fails to reuse the integration and redirects with an error message if saving the new integration fails" do
        new_erroneous_integration = build(:integration, category: "build_channel", providable: create(:github_integration), integrable: app)

        post :reuse, params: {
          integration: {
            existing_integration_id: existing_integration.id,
            category: new_erroneous_integration.category,
            providable: {type: new_erroneous_integration.providable_type}
          }, app_id: app.id
        }

        expect(response).to redirect_to(app_integrations_path(app))
        expect(flash[:error]).to eq("Provider is not allowed for app type: android")
      end
    end
  end
end
