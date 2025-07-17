require "rails_helper"

describe IntegrationListeners::LinearController do
  let(:organization) { create(:organization) }
  let(:app) { create(:app, :android, organization: organization) }
  let(:user) { create(:user, :with_email_authentication, :as_developer, member_organization: organization) }
  let(:state) {
    {
      organization_id: organization.id,
      app_id: app.id,
      integration_category: "project_management",
      integration_provider: "LinearIntegration",
      user_id: user.id
    }.to_json.encode
  }
  let(:code) { "test_code" }
  let(:integration) { build(:integration, :linear, integrable: app) }
  let(:linear_integration) { build(:linear_integration) }

  before do
    sign_in user.email_authentication
    allow_any_instance_of(described_class).to receive(:state_user).and_return(user)
    allow_any_instance_of(described_class).to receive(:state_app).and_return(app)
    allow_any_instance_of(described_class).to receive(:state_organization).and_return(organization)
    allow_any_instance_of(described_class).to receive(:build_providable).and_return(linear_integration)
    allow_any_instance_of(described_class).to receive(:valid_state?).and_return(true)
  end

  describe "#callback" do
    context "when single organization" do
      before do
        allow(app.integrations).to receive(:build).and_return(integration)
        allow(integration).to receive_messages(providable: linear_integration, save!: true, valid?: true)
        allow(linear_integration).to receive_messages(complete_access: true, setup: {})

        get :callback, params: {state: state, code: code}
      end

      it "redirects to app path with success notice" do
        expect(response).to redirect_to(app_path(app))
        expect(flash[:notice]).to eq(I18n.t("integrations.project_management.linear.integration_created"))
      end
    end
  end

  describe "#providable_params" do
    let(:controller_instance) { described_class.new }

    before do
      allow(controller_instance).to receive_messages(
        params: ActionController::Parameters.new(code: "test_code", organization_id: "test_org"),
        code: "test_code"
      )
    end

    it "includes code and organization_id" do
      result = controller_instance.send(:providable_params)
      expect(result).to eq({code: "test_code", integration: nil, workspace_id: "test_org"})
    end
  end
end
