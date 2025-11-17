require "rails_helper"

describe ReleasesController do
  let(:app) { create(:app, :android) }
  let(:organization) { app.organization }
  let(:train) { create(:train, app:, soak_period_enabled: true, soak_period_hours: 24) }
  let(:release) { create(:release, :on_track, train:) }
  let(:release_pilot) { release.train.app.organization.owner }
  let(:other_user) { create(:user, :with_email_authentication, :as_developer, member_organization: organization) }

  describe "PATCH #end_soak" do
    context "when user is release pilot" do
      before do
        sign_in release_pilot.email_authentication
        release.update!(soak_started_at: 1.hour.ago)
      end

      it "ends the soak period successfully" do
        patch :end_soak, params: {id: release.id}

        expect(response).to redirect_to(soak_release_path(release))
        expect(flash[:notice]).to eq("Soak period has been ended early.")
      end

      it "actually ends the soak period" do
        freeze_time do
          patch :end_soak, params: {id: release.id}
          expect(release.reload.soak_period_completed?).to eq(true)
        end
      end

      context "when soak period cannot be ended" do
        before do
          release.update!(soak_started_at: nil)
        end

        it "redirects with error message" do
          patch :end_soak, params: {id: release.id}

          expect(response).to have_http_status(:redirect)
          expect(flash[:error]).to eq("Unable to end soak period.")
        end
      end
    end

    context "when user is not release pilot" do
      before do
        sign_in other_user.email_authentication
        release.update!(soak_started_at: 1.hour.ago)
      end

      it "redirects with error message" do
        patch :end_soak, params: {id: release.id}

        expect(response).to have_http_status(:redirect)
        expect(flash[:error]).to eq("Unable to end soak period.")
      end

      it "does not end the soak period" do
        original_started_at = release.soak_started_at

        patch :end_soak, params: {id: release.id}

        expect(release.reload.soak_started_at).to eq(original_started_at)
      end
    end
  end

  describe "PATCH #extend_soak" do
    context "when user is release pilot" do
      before do
        sign_in release_pilot.email_authentication
        release.update!(soak_started_at: 1.hour.ago)
      end

      it "extends the soak period successfully with provided hours" do
        patch :extend_soak, params: {id: release.id, additional_hours: 12}

        expect(response).to redirect_to(soak_release_path(release))
        expect(flash[:notice]).to eq("Soak period has been extended by 12 hours.")
      end

      it "actually extends the soak period" do
        original_end_time = release.soak_end_time

        patch :extend_soak, params: {id: release.id, additional_hours: 12}

        new_end_time = release.reload.soak_end_time
        expect(new_end_time).to be_within(1.second).of(original_end_time + 12.hours)
      end

      it "defaults to 24 hours when additional_hours is not provided" do
        patch :extend_soak, params: {id: release.id}

        expect(flash[:notice]).to eq("Soak period has been extended by 24 hours.")
      end

      it "defaults to 24 hours when additional_hours is 0" do
        patch :extend_soak, params: {id: release.id, additional_hours: 0}

        expect(flash[:notice]).to eq("Soak period has been extended by 24 hours.")
      end

      it "defaults to 24 hours when additional_hours is negative" do
        patch :extend_soak, params: {id: release.id, additional_hours: -5}

        expect(flash[:notice]).to eq("Soak period has been extended by 24 hours.")
      end

      it "accepts custom extension hours" do
        patch :extend_soak, params: {id: release.id, additional_hours: 48}

        expect(flash[:notice]).to eq("Soak period has been extended by 48 hours.")
      end

      context "when soak period cannot be extended" do
        before do
          release.update!(soak_started_at: nil)
        end

        it "redirects with error message" do
          patch :extend_soak, params: {id: release.id, additional_hours: 12}

          expect(response).to have_http_status(:redirect)
          expect(flash[:error]).to eq("Unable to extend soak period.")
        end
      end
    end

    context "when user is not release pilot" do
      before do
        sign_in other_user.email_authentication
        release.update!(soak_started_at: 1.hour.ago)
      end

      it "redirects with error message" do
        patch :extend_soak, params: {id: release.id, additional_hours: 12}

        expect(response).to have_http_status(:redirect)
        expect(flash[:error]).to eq("Unable to extend soak period.")
      end

      it "does not extend the soak period" do
        original_started_at = release.soak_started_at

        patch :extend_soak, params: {id: release.id, additional_hours: 12}

        expect(release.reload.soak_started_at).to eq(original_started_at)
      end
    end
  end
end
