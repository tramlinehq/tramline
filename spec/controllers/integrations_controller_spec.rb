require "rails_helper"

describe IntegrationsController do
  let(:app) { create(:app, platform: :android) }
  let(:organization) { app.organization }
  let(:app_for_across_integration) { create(:app, platform: :android, organization: organization, bundle_identifier: "com.abc.com") }
  let(:user) { create(:user, :with_email_authentication, :as_developer, member_organization: organization) }
  let(:existing_integration) { create(:integration, status: "connected", category: "version_control", providable: create(:github_integration), integrable: app, metadata: {id: Faker::Number.number(digits: 8)}) }
  let(:existing_integration_across_app) { create(:integration, status: "connected", category: "version_control", providable: create(:github_integration), integrable: app_for_across_integration, metadata: {id: Faker::Number.number(digits: 8)}) }
  let(:integration) { create(:integration, category: "ci_cd", providable: create(:github_integration), integrable: app) }

  before do
    sign_in user.email_authentication
    allow_any_instance_of(described_class).to receive(:current_user).and_return(user)
  end

  describe "POST #reuse" do
    before do
      allow_any_instance_of(described_class).to receive(:set_integration)
      allow(Integration).to receive(:find_by).with(id: existing_integration.id.to_s).and_return(existing_integration)
    end

    context "when the existing integration is not connected or does not exist" do
      it "redirects to the integrations path with an error message" do
        existing_integration.update(status: "disconnected")
        post :reuse, params: {id: existing_integration.id, app_id: app.id}

        expect(response).to redirect_to(app_integrations_path(app))
        expect(flash[:alert]).to eq("Integration not found or not connected.")
      end
    end

    context "when the existing integration is connected" do
      it "reuses the integration and redirects to the integrations path with a success message" do
        new_integration = instance_double(Integration, save: true)
        allow(controller).to receive(:initiate_integration).and_return(new_integration)

        post :reuse, params: {id: existing_integration.id, app_id: app.id}

        expect(response).to redirect_to(app_integrations_path(app))
        expect(flash[:notice]).to eq("#{existing_integration.providable_type} integration reused successfully.")
      end

      it "fails to reuse the integration and redirects with an error message if saving the new integration fails" do
        new_integration = instance_double(Integration, save: false, errors: instance_double(ActiveModel::Errors, full_messages: ["Save failed"]))
        allow(controller).to receive(:initiate_integration).and_return(new_integration)

        post :reuse, params: {id: existing_integration.id, app_id: app.id}

        expect(response).to redirect_to(app_integrations_path(app))
        expect(flash[:error]).to eq("Save failed")
      end
    end
  end

  describe "POST #reuse_integration_across_app" do
    context "when the existing integration is connected" do
      it "reuses the integration and redirects to the integrations path with a success message" do
        post :reuse_integration_across_app, params: {app_id: app.id, integration: {id: existing_integration_across_app.id, category: existing_integration_across_app.category}}

        expect(response).to redirect_to(app_integrations_path(app))
        expect(flash[:notice]).to eq("#{existing_integration_across_app.providable_type} across app integration reused successfully.")
      end
    end

    context "when the existing integration across app is not connected or does not exist" do
      it "redirects to the integrations path with an error message" do
        existing_integration_across_app.update(status: "disconnected")

        post :reuse_integration_across_app, params: {app_id: app.id, integration: {id: existing_integration_across_app.id, category: existing_integration_across_app.category}}
        expect(response).to redirect_to(app_integrations_path(app))
        expect(flash[:alert]).to eq("Integration not found or not connected.")
      end

      it "fails to reuse the integration across app and redirects with an error message if saving the new integration fails" do
        new_integration = instance_double(Integration, save: false, errors: instance_double(ActiveModel::Errors, full_messages: ["Save failed"]))
        allow(controller).to receive(:initiate_integration).and_return(new_integration)

        post :reuse_integration_across_app, params: {app_id: app.id, integration: {id: existing_integration_across_app.id, category: existing_integration_across_app.category}}
        expect(response).to redirect_to(app_integrations_path(app))
        expect(flash[:error]).to eq("Save failed")
      end
    end
  end
end
