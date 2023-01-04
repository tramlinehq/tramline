require "rails_helper"

RSpec.describe "Accounts::Releases::SignOffs", type: :request do
  let(:step) { create(:releases_step, :with_deployment) }
  let(:organization) { step.train.app.organization }
  let(:user) { create(:user, :as_developer, confirmed_at: Time.now, member_organization: organization) }

  let(:sign_off_group) { create(:sign_off_group, members: [user]) }
  let(:commit) { create(:releases_commit) }

  describe "GET /create" do
    it "returns http success" do
      sign_in user
      post "/steps/#{step.id}/sign_off/approve", params: {sign_off_group_id: sign_off_group.id, commit_id: commit.id}
      expect(response).to have_http_status(302)
      expect(SignOff.count).to eq(1)
    end
  end
end
