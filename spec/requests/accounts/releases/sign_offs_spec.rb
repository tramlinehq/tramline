require "rails_helper"

RSpec.describe "Accounts::Releases::SignOffs", type: :request do
  let(:step) { create(:releases_step) }
  let(:organization) { step.train.app.organization }
  let(:user) { create(:accounts_user, confirmed_at: Time.zone.now, organizations: [organization]) }
  let(:sign_off_group) { create(:sign_off_group, members: [user]) }
  let(:commit) { create(:releases_commit) }

  describe "GET /create" do
    it "returns http success" do
      sign_in user
      post "/steps/#{step.id}/sign_off/approve", params: {sign_off_group_id: sign_off_group.id, commit_id: commit.id}
      expect(response).to have_http_status(:found)
      expect(SignOff.count).to eq(1)
    end
  end
end
