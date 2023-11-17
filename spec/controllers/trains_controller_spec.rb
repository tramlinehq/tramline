require "rails_helper"

describe TrainsController do
  describe "GET #show" do
    let(:old_app_slug) { "old-app-slug" }
    let(:new_app_slug) { "new-app-slug" }
    let(:train) { create(:train) }
    let(:app) { train.app }
    let(:organization) { app.organization }
    let(:user) { create(:user, :as_developer, confirmed_at: Time.zone.now, member_organization: organization) }

    before do
      sign_in user
    end

    it "returns success code" do
      get :show, params: {app_id: app.slug, id: train.slug}
      expect(response).to have_http_status(:ok)
    end

    it "redirects to new slug when redirect configured" do
      app.update!(slug: new_app_slug)
      get :show, params: {app_id: old_app_slug, id: train.slug}
      expect(response).to redirect_to(app_train_path(app_id: app.slug, id: train.slug))
    end
  end
end
