require "rails_helper"

describe IntegrationsController do
  let(:app) { create(:app, platform: :android) }
  let(:organization) { app.organization }
  let(:user) { create(:user, :with_email_authentication, :as_developer, member_organization: organization) }
  let(:existing_integration) { create(:integration, status: "connected", category: "version_control", providable: create(:github_integration), integrable: app, metadata: {id: Faker::Number.number(digits: 8)}) }
  let(:integration) { create(:integration, category: "ci_cd", providable: create(:github_integration), integrable: app) }

  before do
    sign_in user.email_authentication
    allow_any_instance_of(described_class).to receive(:current_user).and_return(user)
    allow_any_instance_of(described_class).to receive(:set_integration)
  end

  describe "POST #reuse" do
    context "when the existing integration is not connected or does not exist" do
      it "redirects to the integrations path with an error message" do
        post :reuse, params: {id: Faker::Internet.uuid, app_id: app.id}

        expect(response).to redirect_to(app_integrations_path(app))
        expect(flash[:alert]).to eq("Integration not found or not connected.")
      end
    end

    context "when the existing integration is connected" do
      before do
        allow(Integration).to receive(:find_by).with(id: existing_integration.id.to_s).and_return(existing_integration)
      end

      it "reuses the integration and redirects to the integrations path with a success message" do
        new_integration = instance_double(Integration, save: true)
        allow(controller).to receive(:build_new_integration).and_return(new_integration)

        post :reuse, params: {id: existing_integration.id, app_id: app.id}

        expect(response).to redirect_to(app_integrations_path(app))
        expect(flash[:notice]).to eq("#{existing_integration.providable_type} integration reused successfully.")
      end

      it "fails to reuse the integration and redirects with an error message if saving the new integration fails" do
        new_integration = instance_double(Integration, save: false, errors: instance_double(ActiveModel::Errors, full_messages: ["Save failed"]))
        allow(controller).to receive(:build_new_integration).and_return(new_integration)

        post :reuse, params: {id: existing_integration.id, app_id: app.id}

        expect(response).to redirect_to(app_integrations_path(app))
        expect(flash[:error]).to eq("Save failed")
      end
    end
  end
end
