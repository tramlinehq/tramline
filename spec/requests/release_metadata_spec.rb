require "rails_helper"

describe "ReleaseMetadata" do
  describe "GET /metadata" do
    let(:train) { create(:train) }
    let(:release_platform) { create(:release_platform, train:, platform: "android") }
    let(:release) { create(:release, :created, :with_no_platform_runs) }
    let(:organization) { release.train.app.organization }
    let(:user) { create(:user, :with_email_authentication, :as_developer, member_organization: organization) }

    it "renders the release notes textareas for an existing locale" do
      run = create(:release_platform_run, release:, release_platform:)
      run.release_metadata.first&.update!(locale: "en-US") || create(:release_metadata, release:, release_platform_run: run, locale: "en-US")

      sign_in user.email_authentication
      get release_metadata_edit_path(release.id),
        headers: {"User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36"}

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Now editing")
      expect(response.body).to include("Release Notes")
      expect(response.body).to include("<textarea")
    end
  end
end
