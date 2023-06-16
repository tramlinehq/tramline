require "rails_helper"

describe "Accounts::Releases::Releases" do
  describe "GET /show" do
    let(:release) { create(:release, :created) }
    let(:organization) { release.train.app.organization }
    let(:user) { create(:user, :as_developer, confirmed_at: Time.zone.now, member_organization: organization) }
    let(:release_platform) { create(:release_platform, train: release.train) }

    it "returns success code" do
      create(:release_platform_run, :created, release:, release_platform:)
      sign_in user
      get release_path(release.id)
      expect(response).to have_http_status(:ok)
    end
  end
end
