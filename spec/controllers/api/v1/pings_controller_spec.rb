require "rails_helper"

describe Api::V1::PingsController do
  it "is successful" do
    get :show, format: :json
    expect(response).to have_http_status(:success)
  end
end
