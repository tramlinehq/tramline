require "rails_helper"

RSpec.describe "Connections", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get "/connection/index"
      expect(response).to have_http_status(:success)
    end
  end
end
