require "rails_helper"

RSpec.describe "Accounts::Releases::SignOffs", type: :request do
  let(:step) { FactoryBot.create(:releases_step) }
  let(:organization) { step.train.app.organization }
  let(:user) { FactoryBot.create(:accounts_user, confirmed_at: Time.now, organizations: [organization]) }
  let(:sign_off_group) { FactoryBot.create(:sign_off_group, members: [user]) }
  let(:commit) {FactoryBot.create(:releases_commit)}

  describe "GET /create" do
    it "returns http success" do
      sign_in user
      post "/steps/#{step.id}/sign_off", params: {sign_off_group_id: sign_off_group.id, commit_id: commit.id}
      expect(response).to have_http_status(302)
      expect(SignOff.count).to eq(1)
    end
  end
end
