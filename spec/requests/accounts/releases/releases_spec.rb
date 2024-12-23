require "rails_helper"

describe "Accounts::Releases::Releases" do
  describe "GET /overview" do
    let(:train) { create(:train) }
    let(:release_platform) { create(:release_platform, train:) }
    let(:release) { create(:release, :created, :with_no_platform_runs) }
    let(:organization) { release.train.app.organization }
    let(:user) { create(:user, :with_email_authentication, :as_developer, member_organization: organization) }

    it "returns success code" do
      create(:release_platform_run, :created, release:, release_platform:)

      sign_in user.email_authentication
      get overview_release_path(release.id)

      expect(response).to have_http_status(:ok)
    end
  end
end
