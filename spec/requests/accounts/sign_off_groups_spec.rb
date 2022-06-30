require "rails_helper"

RSpec.describe "Accounts::SignOffGroups", type: :request do
  let(:organization) { FactoryBot.create(:organization) }
  let(:tram_app) { FactoryBot.create(:app, organization:) }
  let(:user) { FactoryBot.create(:accounts_user, confirmed_at: Time.now, organizations: [organization]) }
  let(:developer_1) { FactoryBot.create(:accounts_user, confirmed_at: Time.now, organizations: [organization]) }
  let(:qa_1) { FactoryBot.create(:accounts_user, confirmed_at: Time.now, organizations: [organization]) }

  describe "GET /edit" do
    it "returns http success" do
      sign_in user
      get "/apps/#{tram_app.id}/sign_off_groups/edit"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /update" do
    it "returns http success" do
      sign_in user
      put "/apps/#{tram_app.slug}/sign_off_groups",
        params: {app: {sign_off_groups_attributes: [
          {name: "Developers", sign_off_group_membership_ids: [developer_1.id]},
          {name: "Testers", sign_off_group_membership_ids: [qa_1.id]}
        ]}}

      expect(tram_app.sign_off_groups.count).to eq(2)
      expect(response).to have_http_status(302)
    end
  end
end
