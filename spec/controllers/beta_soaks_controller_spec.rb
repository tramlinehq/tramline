require "rails_helper"

describe BetaSoaksController do
  let(:app) { create(:app, :android) }
  let(:organization) { app.organization }
  let(:train) { create(:train, app:, soak_period_enabled: true, soak_period_hours: 24) }
  let(:release) { create(:release, :on_track, train:) }
  let(:user) { release.train.app.organization.owner }
  let(:other_user) { create(:user, :with_email_authentication, :as_viewer, member_organization: organization) }

  describe "POST #end_soak" do
    context "when user is release pilot" do
      before do
        sign_in user.email_authentication
        create(:beta_soak, :active, release: release)
      end

      it "ends the soak period successfully" do
        post :end_soak, params: {release_id: release.id}

        expect(response).to redirect_to(release_beta_soak_path(release))
        expect(flash[:notice]).to eq("Soak period has been ended early.")
      end

      it "actually ends the soak period" do
        freeze_time do
          post :end_soak, params: {release_id: release.id}
          expect(release.reload.beta_soak&.ended_at).to be_present
        end
      end

      context "when soak period cannot be ended" do
        before do
          # No beta_soak created, remove the active one
          release.beta_soak&.destroy
        end

        it "redirects with error message" do
          post :end_soak, params: {release_id: release.id}
          expect(response).to have_http_status(:redirect)
          expect(flash[:error]).to eq("Unable to end soak period.")
        end
      end
    end

    context "when user is not authorized (viewer role)" do
      before do
        sign_in other_user.email_authentication
        create(:beta_soak, :active, release: release)
      end

      it "redirects with authorization error message" do
        post :end_soak, params: {release_id: release.id}
        expect(response).to have_http_status(:redirect)
        expect(flash[:error]).to eq("You are not authorized to perform this action.")
      end

      it "does not end the soak period" do
        original_beta_soak = release.beta_soak
        post :end_soak, params: {release_id: release.id}
        expect(release.reload.beta_soak.started_at).to eq(original_beta_soak.started_at)
        expect(release.reload.beta_soak.ended_at).to be_nil
      end
    end
  end

  describe "POST #extend_soak" do
    context "when user is release pilot" do
      before do
        sign_in user.email_authentication
        create(:beta_soak, :active, release: release)
      end

      it "extends the soak period successfully with provided hours" do
        post :extend_soak, params: {release_id: release.id, additional_hours: 12}

        expect(response).to redirect_to(release_beta_soak_path(release))
        expect(flash[:notice]).to eq("Soak period has been extended by 12 hour(s).")
      end

      it "actually extends the soak period" do
        original_period_hours = release.beta_soak.period_hours
        post :extend_soak, params: {release_id: release.id, additional_hours: 12}
        new_period_hours = release.reload.beta_soak.period_hours
        expect(new_period_hours).to eq(original_period_hours + 12)
      end

      it "defaults to 1 hour when additional_hours is not provided" do
        post :extend_soak, params: {release_id: release.id}
        expect(flash[:notice]).to eq("Soak period has been extended by 1 hour(s).")
      end

      it "defaults to 1 hour when additional_hours is 0" do
        post :extend_soak, params: {release_id: release.id, additional_hours: 0}
        expect(flash[:notice]).to eq("Soak period has been extended by 1 hour(s).")
      end

      it "defaults to 1 hour when additional_hours is negative" do
        post :extend_soak, params: {release_id: release.id, additional_hours: -5}
        expect(flash[:notice]).to eq("Soak period has been extended by 1 hour(s).")
      end

      it "accepts custom extension hours" do
        post :extend_soak, params: {release_id: release.id, additional_hours: 48}
        expect(flash[:notice]).to eq("Soak period has been extended by 48 hour(s).")
      end

      context "when soak period cannot be extended" do
        before do
          # No beta_soak created, remove the active one
          release.beta_soak&.destroy
        end

        it "redirects with error message" do
          post :extend_soak, params: {release_id: release.id, additional_hours: 12}
          expect(response).to have_http_status(:redirect)
          expect(flash[:error]).to be_present
        end
      end
    end

    context "when user is not authorized (viewer role)" do
      before do
        sign_in other_user.email_authentication
        create(:beta_soak, :active, release: release)
      end

      it "redirects with authorization error message" do
        post :extend_soak, params: {release_id: release.id, additional_hours: 12}
        expect(response).to have_http_status(:redirect)
        expect(flash[:error]).to eq("You are not authorized to perform this action.")
      end

      it "does not extend the soak period" do
        original_period_hours = release.beta_soak.period_hours
        post :extend_soak, params: {release_id: release.id, additional_hours: 12}
        expect(release.reload.beta_soak.period_hours).to eq(original_period_hours)
      end
    end
  end

  describe "GET #show" do
    before do
      sign_in user.email_authentication
      create(:beta_soak, :active, release: release)
    end

    it "renders successfully" do
      get :show, params: {release_id: release.id}
      expect(response).to have_http_status(:success)
    end
  end
end
