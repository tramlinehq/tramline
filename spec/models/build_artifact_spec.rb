require 'rails_helper'

RSpec.describe BuildArtifact, type: :model do
  describe "#active_storage_service" do
    let(:build_artifact) { create(:build_artifact) }

    context "when organization does not have custom storage" do
      it "returns the default storage service" do
        expect(build_artifact.active_storage_service).to eq(Rails.application.config.active_storage.service)
      end
    end

    context "when organization has custom storage" do
      let(:organization) { create(:organization) }
      let!(:custom_storage) { create(:accounts_custom_storage, organization: organization) }
      let(:app) { create(:app, organization: organization) }
      let(:release_platform_run) { create(:release_platform_run, app: app) }
      let(:build) { create(:build, release_platform_run: release_platform_run) }
      let(:build_artifact) { create(:build_artifact, build: build) }

      it "returns the custom storage service configuration" do
        expected_service_config = {
          service: "GCS",
          project: custom_storage.project_id,
          credentials: custom_storage.credentials,
          bucket: custom_storage.bucket
        }

        expect(build_artifact.active_storage_service).to eq(expected_service_config)
      end
    end
  end
end
