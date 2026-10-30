require "rails_helper"

describe CiCd::BitbucketConfigsController do
  render_views

  let(:organization) { create(:organization) }
  let(:app) { create(:app, platform: :android, organization:) }
  let(:user) { create(:user, :with_email_authentication, :as_developer, member_organization: organization) }

  before do
    create(:integration, :with_bitbucket, integrable: app, category: "ci_cd")
    allow(controller).to receive(:current_user).and_return(user)
    request.headers["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"
  end

  it "updates the frame with the error when switching workspaces fails" do
    allow_any_instance_of(BitbucketIntegration).to receive(:workspaces).and_return(["tramline"])
    allow_any_instance_of(BitbucketIntegration).to receive(:repos).and_raise(Installations::Error::TokenRefreshFailure)

    get :edit, params: {app_id: app.slug, workspace: "tramline"}, format: :turbo_stream

    expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
    expect(response.body).to include('<turbo-stream action="update" target="ci_cd_config">')
    expect(response.body).to include("The connection to Bitbucket has expired.")
  end
end
