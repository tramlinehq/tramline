require "rails_helper"

describe ApprovalItemsController do
  let(:organization) { create(:organization) }
  let(:current_user) { create(:user) }

  before do
    allow(controller).to receive_messages(current_user: current_user, current_organization: organization)
  end

  describe "GET #index" do
    it "returns 200 when approvals are enabled" do
      train = create(:train, approvals_enabled: true)
      release = create(:release, train:)

      get :index, params: {release_id: release.id}
      expect(response).to be_successful
    end

    it "redirects to the release page when approvals are disabled" do
      train = create(:train, approvals_enabled: false)
      release = create(:release, train:)

      get :index, params: {release_id: release.id}
      expect(response).to redirect_to(release_path(release))
      expect(flash[:error]).to eq("Approvals are disabled for this release.")
    end
  end
end
