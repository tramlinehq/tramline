require "rails_helper"

RSpec.describe "Accounts::Releases::Releases", type: :request do
  describe "GET /show" do
    let(:release) { create(:releases_train_run) }
    let(:organization) { release.train.app.organization }
    let(:user) { create(:accounts_user, confirmed_at: Time.zone.now, organizations: [organization]) }

    it "returns success code" do
      sign_in user
      get release_path(release.id)
      expect(response).to have_http_status(:ok)
    end
  end
end
