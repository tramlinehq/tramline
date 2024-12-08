require "rails_helper"

describe ApprovalItemsController do
  let(:organization) { create(:organization, :with_owner_membership) }
  let(:app) { create(:app, :android, organization:) }
  let(:current_user) { create(:user, unique_authn_id: Faker::Internet.email) }

  before do
    create(:membership, user: current_user, organization: organization, role: "developer")
    allow(controller).to receive_messages(current_user: current_user, current_organization: organization)
  end

  describe "GET #index" do
    it "returns 200 when approvals are enabled" do
      train = create(:train, approvals_enabled: true, app:)
      release = create(:release, train:)

      get :index, params: {release_id: release.id}
      expect(response).to be_successful
    end

    it "redirects to the release page when approvals are disabled" do
      train = create(:train, approvals_enabled: false, app:)
      release = create(:release, train:)

      get :index, params: {release_id: release.id}
      expect(response).to redirect_to(release_path(release))
      expect(flash[:error]).to eq("Approvals are disabled for this release.")
    end
  end

  describe "PATCH #update" do
    it "refreshes the stream with a flash when no item is found" do
      train = create(:train, approvals_enabled: true, app:)
      release = create(:release, train:)

      patch :update, params: {id: 1, release_id: release.id}

      expect(response).to be_successful
      expect(flash[:error]).to eq(I18n.t("approval_items.not_found"))
      expect(response.body).to include("list_approval_items")
      expect(response.content_type).to eq "text/vnd.turbo-stream.html; charset=utf-8"
    end

    it "updates the status and refreshes the stream" do
      train = create(:train, approvals_enabled: true, app:)
      release = create(:release, train:, release_pilot: current_user)
      item = create(:approval_item, release:, status: "not_started", author: current_user)

      patch :update, params: {id: item.id, release_id: release.id, status: "approved"}

      expect(response).to be_successful
      expect(flash[:success]).to be_nil
      expect(response.body).to include("list_approval_items")
      expect(response.content_type).to eq "text/vnd.turbo-stream.html; charset=utf-8"
    end
  end

  describe "DELETE #destroy" do
    it "refreshes the stream with a flash when no item is found" do
      train = create(:train, approvals_enabled: true, app:)
      release = create(:release, train:)

      delete :destroy, params: {id: 1, release_id: release.id}

      expect(response).to be_successful
      expect(flash[:error]).to eq(I18n.t("approval_items.not_found"))
      expect(response.body).to include("list_approval_items")
      expect(response.content_type).to eq "text/vnd.turbo-stream.html; charset=utf-8"
    end

    it "refreshes the stream with a flash when item is already started" do
      train = create(:train, approvals_enabled: true, app:)
      release = create(:release, train:, release_pilot: current_user)
      item = create(:approval_item, release:, status: "blocked", author: current_user)

      delete :destroy, params: {id: item.id, release_id: release.id}

      expect(response).to be_successful
      expect(item.status).to eq("blocked")
      expect(flash[:notice]).to eq(I18n.t("approval_items.destroy.conflict"))
      expect(response.body).to include("list_approval_items")
      expect(response.content_type).to eq "text/vnd.turbo-stream.html; charset=utf-8"
    end

    it "destroys the item and refreshes the stream" do
      train = create(:train, approvals_enabled: true, app:)
      release = create(:release, train:, release_pilot: current_user)
      item = create(:approval_item, release:, status: "not_started", author: current_user)

      delete :destroy, params: {id: item.id, release_id: release.id}

      expect(response).to be_successful
      expect(release.approval_items).to be_empty
      expect(response.body).to include("list_approval_items")
      expect(response.content_type).to eq "text/vnd.turbo-stream.html; charset=utf-8"
    end
  end
end
