require "rails_helper"

describe VersionControl::BitbucketConfigsController do
  render_views

  let(:organization) { create(:organization) }
  let(:app) { create(:app, platform: :android, organization:) }
  let(:user) { create(:user, :with_email_authentication, :as_developer, member_organization: organization) }

  let!(:bitbucket_integration) { create(:integration, :with_bitbucket, integrable: app).providable }

  before do
    allow(controller).to receive(:current_user).and_return(user)
    request.headers["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"
    request.headers["Turbo-Frame"] = "version_control_config"
  end

  describe "#edit" do
    it "renders the configuration form" do
      allow_any_instance_of(BitbucketIntegration).to receive_messages(workspaces: ["tramline"], repos: [])

      get :edit, params: {app_id: app.slug}

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Select Repository")
    end

    it "asks to re-authorize inside the frame when the token can no longer be refreshed" do
      allow_any_instance_of(BitbucketIntegration).to receive(:workspaces).and_raise(Installations::Error::TokenRefreshFailure)

      get :edit, params: {app_id: app.slug}

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('<turbo-frame id="version_control_config"')
      expect(response.body).to include("The connection to Bitbucket has expired. Re-authorize it from the integrations page and try again.")
    end

    it "shows a load error inside the frame for other api errors" do
      allow_any_instance_of(BitbucketIntegration).to receive(:workspaces).and_raise(Installations::Error.new("Resource not found", reason: :not_found))

      get :edit, params: {app_id: app.slug}

      expect(response.body).to include('<turbo-frame id="version_control_config"')
      expect(response.body).to include("Could not load data from Bitbucket. Please try again in a bit.")
    end

    context "when choosing the workspace" do
      let(:requested_workspaces) { [] }

      before do
        allow_any_instance_of(BitbucketIntegration).to receive(:workspaces).and_return(%w[tramline kredivo])
        allow_any_instance_of(BitbucketIntegration).to receive(:repos) { |_, workspace| requested_workspaces << workspace and [] }
      end

      it "keeps the workspace picked in the form selected and lists its repositories" do
        get :edit, params: {app_id: app.slug, workspace: "kredivo"}, format: :turbo_stream

        expect(requested_workspaces).to eq(["kredivo"])
        expect(response.body).to include('<option selected="selected" value="kredivo">')
      end

      it "uses the saved workspace when none is picked" do
        bitbucket_integration.update!(workspace: "kredivo")

        get :edit, params: {app_id: app.slug}

        expect(requested_workspaces).to eq(["kredivo"])
        expect(response.body).to include('<option selected="selected" value="kredivo">')
      end

      it "falls back to the first workspace when the saved one is no longer accessible" do
        bitbucket_integration.update!(workspace: "renamed-or-removed")

        get :edit, params: {app_id: app.slug}

        expect(requested_workspaces).to eq(["tramline"])
        expect(response.body).to include('<option selected="selected" value="tramline">')
      end

      it "ignores a picked workspace that is not in the accessible list" do
        get :edit, params: {app_id: app.slug, workspace: "someone-elses"}, format: :turbo_stream

        expect(requested_workspaces).to eq(["tramline"])
      end

      it "falls back to the first workspace when none is picked or saved" do
        get :edit, params: {app_id: app.slug}

        expect(requested_workspaces).to eq(["tramline"])
        expect(response.body).to include('<option selected="selected" value="tramline">')
      end
    end
  end
end
