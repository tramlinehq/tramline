require "rails_helper"

describe AppsController do
  describe "GET #show" do
    let(:old_app_slug) { "old-app-slug" }
    let(:new_app_slug) { "new-app-slug" }
    let(:app) { create(:app, :android, slug: old_app_slug) }
    let(:organization) { app.organization }
    let(:user) { create(:user, :as_developer, confirmed_at: Time.zone.now, member_organization: organization) }

    before do
      sign_in user
    end

    it "returns success code" do
      get :show, params: {id: app.slug}
      expect(response).to have_http_status(:ok)
    end

    it "redirects to new slug when redirect configured" do
      app.update!(slug: new_app_slug)
      get :show, params: {id: old_app_slug}
      expect(response).to redirect_to(app_path(id: app.slug))
    end
  end
end
