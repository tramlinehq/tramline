require "rails_helper"

describe "Homes" do
  describe "GET /index" do
    it "returns http success" do
      get "/"
      expect(response).to have_http_status(:found)
    end
  end
end
