require "rails_helper"

describe ReleasePlatformRunsController do
  let(:app) { create(:app, :android) }
  let(:organization) { app.organization }
  let(:train) { create(:train, app:) }
  let(:release) { create(:release, :on_track, train:) }
  let(:release_platform_run) do
    run = release.release_platform_runs.first
    run.update!(status: "on_track")
    run
  end
  let(:user) { release.train.app.organization.owner }
  let(:other_user) { create(:user, :with_email_authentication, :as_viewer, member_organization: organization) }

  describe "PATCH #conclude" do
    context "when user is authorized" do
      before do
        sign_in user.email_authentication
      end

      it "concludes the release platform run successfully" do
        patch :conclude, params: {id: release_platform_run.id}

        expect(response).to have_http_status(:redirect)
        expect(flash[:notice]).to eq("Release platform run was successfully concluded.")
      end

      it "actually concludes the release platform run" do
        expect {
          patch :conclude, params: {id: release_platform_run.id}
        }.to change { release_platform_run.reload.status }.from("on_track").to("concluded")
      end

      context "when release platform run is not active" do
        before do
          release_platform_run.conclude!
        end

        it "redirects with error message" do
          patch :conclude, params: {id: release_platform_run.id}
          expect(response).to have_http_status(:redirect)
          expect(flash[:error]).to be_present
        end
      end
    end

    context "when user is not authorized (viewer role)" do
      before do
        sign_in other_user.email_authentication
      end

      it "redirects with authorization error message" do
        patch :conclude, params: {id: release_platform_run.id}
        expect(response).to have_http_status(:redirect)
        expect(flash[:error]).to eq("You are not authorized to perform this action.")
      end

      it "does not conclude the release platform run" do
        patch :conclude, params: {id: release_platform_run.id}
        expect(release_platform_run.reload.concluded?).to be(false)
      end
    end
  end
end
