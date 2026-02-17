require "rails_helper"

describe Api::V1::WorkflowRunsController do
  let(:organization) { create(:organization, :with_owner_membership) }
  let(:app) { create(:app, :android, organization:, build_number_managed_internally: false) }
  let(:train) { create(:train, app:) }
  let(:release) { create(:release, train:) }
  let(:release_platform_run) { release.release_platform_runs.first }
  let(:workflow_run) { create(:workflow_run, :triggered, release_platform_run:) }

  describe "PATCH #update_build_number" do
    context "when unauthorized" do
      it "returns unauthorized without auth headers" do
        patch :update_build_number, format: :json, params: {id: workflow_run.id, build_number: "12345"}
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns unauthorized with invalid api key" do
        request.headers["HTTP_X_TRAMLINE_ACCOUNT_ID"] = organization.id
        request.headers["Authorization"] = "Bearer invalid_key"
        patch :update_build_number, format: :json, params: {id: workflow_run.id, build_number: "12345"}
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when workflow run not found" do
      before do
        request.headers["HTTP_X_TRAMLINE_ACCOUNT_ID"] = organization.id
        request.headers["Authorization"] = "Bearer #{organization.api_key}"
      end

      it "returns not found for non-existent workflow run" do
        patch :update_build_number, format: :json, params: {id: SecureRandom.uuid, build_number: "12345"}
        expect(response).to have_http_status(:not_found)
      end

      it "returns not found for workflow run from different organization" do
        other_org = create(:organization, :with_owner_membership)
        other_app = create(:app, :android, organization: other_org)
        other_train = create(:train, app: other_app)
        other_release = create(:release, train: other_train)
        other_run = other_release.release_platform_runs.first
        other_workflow_run = create(:workflow_run, :triggered, release_platform_run: other_run)

        patch :update_build_number, format: :json, params: {id: other_workflow_run.id, build_number: "12345"}
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when app has internal build number management" do
      let(:internal_app) { create(:app, :android, organization:, build_number_managed_internally: true) }
      let(:internal_train) { create(:train, app: internal_app) }
      let(:internal_release) { create(:release, train: internal_train) }
      let(:internal_run) { internal_release.release_platform_runs.first }
      let(:internal_workflow_run) { create(:workflow_run, :triggered, release_platform_run: internal_run) }

      before do
        request.headers["HTTP_X_TRAMLINE_ACCOUNT_ID"] = organization.id
        request.headers["Authorization"] = "Bearer #{organization.api_key}"
      end

      it "returns unprocessable entity" do
        patch :update_build_number, format: :json, params: {id: internal_workflow_run.id, build_number: "12345"}
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["error"]).to eq("Build numbers are managed internally for this app")
      end
    end

    context "when authorized and app has external build number management" do
      before do
        request.headers["HTTP_X_TRAMLINE_ACCOUNT_ID"] = organization.id
        request.headers["Authorization"] = "Bearer #{organization.api_key}"
      end

      it "updates the build number successfully" do
        patch :update_build_number, format: :json, params: {id: workflow_run.id, build_number: "12345"}
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["workflow_run"]["id"]).to eq(workflow_run.id)
        expect(response.parsed_body["workflow_run"]["build_number"]).to eq("12345")
      end

      it "updates the build record" do
        expect {
          patch :update_build_number, format: :json, params: {id: workflow_run.id, build_number: "12345"}
        }.to change { workflow_run.build.reload.build_number }.to("12345")
      end

      it "syncs the build number to the app counter" do
        expect {
          patch :update_build_number, format: :json, params: {id: workflow_run.id, build_number: "12345"}
        }.to change { app.reload.build_number }.to(12345)
      end

      it "returns bad request when build_number is missing" do
        patch :update_build_number, format: :json, params: {id: workflow_run.id}
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
