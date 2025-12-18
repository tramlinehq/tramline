require "rails_helper"

describe IntegrationsController do
  let(:app) { create(:app, platform: :android) }
  let(:organization) { app.organization }
  let(:user) { create(:user, :with_email_authentication, :as_developer, member_organization: organization) }
  let(:existing_integration) {
    create(:integration,
      status: "connected",
      category: "version_control",
      providable: create(:github_integration),
      integrable: app,
      metadata: {id: Faker::Number.number(digits: 8)})
  }

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

  describe "GET #reauth" do
    let(:gitlab_integration) { create(:gitlab_integration, :without_callbacks_and_validations) }
    let(:integration) { create(:integration, category: "version_control", integrable: app, providable: gitlab_integration) }

    context "when integration needs reauth" do
      before do
        integration.update!(status: :needs_reauth)
      end

      it "redirects to the integration's install path" do
        install_path = "https://gitlab.com/oauth/authorize?client_id=123&redirect_uri=test&response_type=code&scope=read_user"
        allow_any_instance_of(GitlabIntegration).to receive(:install_path).and_return(install_path)

        get :reauth, params: {id: integration.id, app_id: app.id}

        expect(response).to redirect_to(install_path)
      end

      it "allows external redirects" do
        external_url = "https://gitlab.com/oauth/authorize"
        allow_any_instance_of(GitlabIntegration).to receive(:install_path).and_return(external_url)

        get :reauth, params: {id: integration.id, app_id: app.id}

        expect(response).to redirect_to(external_url)
        expect(response.location).to eq(external_url)
      end
    end

    context "when integration is not found or not in needs_reauth status" do
      it "raises ActiveRecord::RecordNotFound for non-existent integration" do
        expect {
          get :reauth, params: {id: "non-existent", app_id: app.id}
        }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "raises ActiveRecord::RecordNotFound for connected integration" do
        integration.update!(status: :connected)

        expect {
          get :reauth, params: {id: integration.id, app_id: app.id}
        }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "raises ActiveRecord::RecordNotFound for disconnected integration" do
        integration.update!(status: :disconnected)

        expect {
          get :reauth, params: {id: integration.id, app_id: app.id}
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context "when integration belongs to different app" do
      let(:other_app) { create(:app, :android, bundle_identifier: "com.example.com.new", organization: organization) }
      let(:other_integration) { create(:integration, :needs_reauth, category: "version_control", integrable: other_app, providable: create(:gitlab_integration, :without_callbacks_and_validations)) }

      it "raises ActiveRecord::RecordNotFound" do
        expect {
          get :reauth, params: {id: other_integration.id, app_id: app.id}
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
