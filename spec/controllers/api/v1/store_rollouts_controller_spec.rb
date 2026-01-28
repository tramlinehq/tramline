require "rails_helper"

describe Api::V1::StoreRolloutsController do
  let(:organization) { create(:organization, :with_owner_membership) }
  let(:app) { create(:app, :android, organization:) }
  let(:train) { create(:train, app:) }
  let(:release_platform) { create(:release_platform, :android, app:) }

  describe "PATCH #increase" do
    context "when unauthorized" do
      it "returns unauthorized without auth headers" do
        patch :increase, params: {app_id: app.slug, release_id: "some-release"}
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns unauthorized with invalid api key" do
        request.headers["HTTP_X_TRAMLINE_ACCOUNT_ID"] = organization.id
        request.headers["Authorization"] = "Bearer invalid_key"
        patch :increase, params: {app_id: app.slug, release_id: "some-release"}
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when authorized" do
      before do
        request.headers["HTTP_X_TRAMLINE_ACCOUNT_ID"] = organization.id
        request.headers["Authorization"] = "Bearer #{organization.api_key}"
      end

      context "when release not found" do
        it "returns not found for nonexistent release" do
          patch :increase, params: {app_id: app.slug, release_id: "nonexistent"}
          expect(response).to have_http_status(:not_found)
        end

        it "returns not found when release belongs to different app" do
          other_app = create(:app, :android, organization:)
          other_train = create(:train, app: other_app)
          other_release = create(:release, train: other_train)

          patch :increase, params: {app_id: app.slug, release_id: other_release.branch_name}
          expect(response).to have_http_status(:not_found)
        end
      end

      context "when release exists but no android rollout" do
        let(:rollout_tree) {
          create_production_rollout_tree(
            train,
            release_platform,
            release_traits: [:on_track],
            run_status: :on_track,
            parent_release_status: :inflight,
            rollout_status: :started,
            skip_rollout: true
          )
        }

        it "returns not found when no rollout exists" do
          release = rollout_tree[:release]
          patch :increase, params: {app_id: app.slug, release_id: release.branch_name}
          expect(response).to have_http_status(:not_found)
        end
      end

      context "when rollout exists but not started" do
        let(:rollout_tree) {
          create_production_rollout_tree(
            train,
            release_platform,
            release_traits: [:on_track],
            run_status: :on_track,
            parent_release_status: :inflight,
            rollout_status: :created
          )
        }

        it "returns unprocessable entity" do
          release = rollout_tree[:release]
          patch :increase, params: {app_id: app.slug, release_id: release.branch_name}
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.parsed_body["error"]).to include("not started")
        end
      end

      context "when rollout can be increased" do
        let(:rollout_tree) {
          create_production_rollout_tree(
            train,
            release_platform,
            release_traits: [:on_track],
            run_status: :on_track,
            parent_release_status: :inflight,
            rollout_status: :started
          )
        }
        let(:providable_dbl) { instance_double(GooglePlayStoreIntegration) }

        before do
          allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new)
          allow_any_instance_of(PlayStoreRollout).to receive(:provider).and_return(providable_dbl)
          allow(StoreSubmissions::PlayStore::UpdateExternalReleaseJob).to receive(:perform_async)
        end

        it "increases the rollout and returns success" do
          release = rollout_tree[:release]
          patch :increase, params: {app_id: app.slug, release_id: release.branch_name}
          expect(response).to have_http_status(:ok)
        end

        it "returns rollout info in the response" do
          release = rollout_tree[:release]
          patch :increase, params: {app_id: app.slug, release_id: release.branch_name}
          rollout_response = response.parsed_body["rollout"]
          expect(rollout_response).to include(
            "status",
            "current_stage",
            "rollout_percentage",
            "is_staged_rollout",
            "platform"
          )
        end

        it "finds release by branch name" do
          release = rollout_tree[:release]
          patch :increase, params: {app_id: app.slug, release_id: release.branch_name}
          expect(response).to have_http_status(:ok)
        end

        it "finds release by slug" do
          release = rollout_tree[:release]
          patch :increase, params: {app_id: app.slug, release_id: release.slug}
          expect(response).to have_http_status(:ok)
        end

        it "finds release by id" do
          release = rollout_tree[:release]
          patch :increase, params: {app_id: app.slug, release_id: release.id}
          expect(response).to have_http_status(:ok)
        end
      end

      context "when rollout increase fails" do
        let(:rollout_tree) {
          create_production_rollout_tree(
            train,
            release_platform,
            release_traits: [:on_track],
            run_status: :on_track,
            parent_release_status: :inflight,
            rollout_status: :started
          )
        }
        let(:providable_dbl) { instance_double(GooglePlayStoreIntegration) }
        let(:play_store_error) { Installations::Google::PlayDeveloper::Error.new("status" => "INVALID_ARGUMENT", "code" => 400, "message" => "Some error") }

        before do
          allow(providable_dbl).to receive(:rollout_release).and_return(GitHub::Result.new { raise play_store_error })
          allow_any_instance_of(PlayStoreRollout).to receive(:provider).and_return(providable_dbl)
        end

        it "returns unprocessable entity with error message" do
          release = rollout_tree[:release]
          patch :increase, params: {app_id: app.slug, release_id: release.branch_name}
          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.parsed_body["error"]).to be_present
        end
      end
    end
  end
end
