require "rails_helper"

describe Config::ReleasePlatformsController do
  let(:train) { create(:train, :with_no_platforms) }
  let(:app) { train.app }
  let(:release_platform) { create(:release_platform, train:, platform: "android") }
  let(:config) { release_platform.platform_config }
  let(:rc_workflow) { config.release_candidate_workflow }
  let(:user) { app.organization.owner }

  before do
    sign_in user.email_authentication
    # Simulate the CI provider handing back an empty/stale workflow list (transient API
    # failure or a cached miss). The configured workflows still exist on the config.
    allow_any_instance_of(Train).to receive(:workflows).and_return([])
    allow_any_instance_of(App).to receive(:ready?).and_return(true)
  end

  describe "GET #edit" do
    it "renders successfully even when the provider returns no workflows" do
      get :edit, params: {app_id: app.id, train_id: train.to_param, platform_id: release_platform.platform}

      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH #update" do
    let(:params) do
      {
        app_id: app.id,
        train_id: train.to_param,
        platform_id: release_platform.platform,
        config_release_platform: {
          production_release_enabled: "true",
          release_candidate_workflow_attributes: {
            id: rc_workflow.id,
            identifier: rc_workflow.identifier
          },
          production_release_attributes: {
            id: config.production_release.id,
            submissions_attributes: {
              "0" => {
                id: config.production_release.submissions.first.id,
                rollout_enabled: "true",
                rollout_stages: "1, 5, 10, 50, 100"
              }
            }
          }
        }
      }
    end

    context "when the CI provider returns no workflows" do
      it "saves unrelated settings without wiping the configured RC workflow" do
        patch :update, params: params

        expect(flash[:error]).to be_blank
        expect(flash[:notice]).to be_present
      end

      it "preserves the already-configured release candidate workflow" do
        original_identifier = rc_workflow.identifier
        original_name = rc_workflow.name

        patch :update, params: params

        config.reload
        expect(config.release_candidate_workflow.identifier).to eq(original_identifier)
        expect(config.release_candidate_workflow.name).to eq(original_name)
      end

      it "applies the edited rollout sequence" do
        patch :update, params: params

        config.reload
        expect(config.production_release.submissions.first.rollout_stages).to eq([1.0, 5.0, 10.0, 50.0, 100.0])
      end
    end
  end
end
