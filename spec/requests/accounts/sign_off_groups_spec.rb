require "rails_helper"

describe "Accounts::SignOffGroups", type: :request do
  let(:organization) { create(:organization) }
  let(:tram_app) { create(:app, :android, organization:) }
  let(:user) { create(:user, :as_developer, confirmed_at: Time.zone.now, member_organization: organization) }
  let(:qa_1) { create(:user, :as_developer, confirmed_at: Time.zone.now, member_organization: organization) }
  let(:developer_1) { create(:user, :as_developer, confirmed_at: Time.zone.now, member_organization: organization) }

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
        params: {
          app: {
            sign_off_groups_attributes: [
              {name: "Developers", member_ids: [developer_1.id]},
              {name: "Testers", member_ids: [qa_1.id]}
            ]
          }
        }

      expect(tram_app.sign_off_groups.count).to eq(2)
      expect(response).to have_http_status(:found)
    end
  end
end
