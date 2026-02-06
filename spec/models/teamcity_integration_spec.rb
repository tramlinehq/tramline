require "rails_helper"

RSpec.describe TeamcityIntegration, type: :model do
  describe "validations" do
    it { should validate_presence_of(:server_url) }
    it { should validate_presence_of(:access_token) }

    describe "cloudflare credentials validation" do
      it "allows both credentials to be blank" do
        integration = build(:teamcity_integration, :without_callbacks_and_validations,
          cf_access_client_id: nil,
          cf_access_client_secret: nil)
        expect(integration).to be_valid
      end

      it "allows both credentials to be present" do
        integration = build(:teamcity_integration, :without_callbacks_and_validations, :with_cloudflare)
        expect(integration).to be_valid
      end

      it "rejects only client_id present" do
        integration = build(:teamcity_integration, :without_callbacks_and_validations,
          cf_access_client_id: "abc.access",
          cf_access_client_secret: nil)
        expect(integration).not_to be_valid
      end

      it "rejects only client_secret present" do
        integration = build(:teamcity_integration, :without_callbacks_and_validations,
          cf_access_client_id: nil,
          cf_access_client_secret: "secret123")
        expect(integration).not_to be_valid
      end
    end
  end

  describe "#cloudflare_credentials" do
    it "returns nil when no cloudflare credentials" do
      integration = build(:teamcity_integration, :without_callbacks_and_validations)
      expect(integration.cloudflare_credentials).to be_nil
    end

    it "returns credentials hash when both are present" do
      integration = build(:teamcity_integration, :without_callbacks_and_validations, :with_cloudflare)
      expect(integration.cloudflare_credentials).to eq({
        client_id: "abc123.access",
        client_secret: "secret456"
      })
    end
  end

  describe "#workflows" do
    let(:app) { create(:app, :android) }
    let(:installation) { instance_double(Installations::Teamcity::Api) }
    let(:teamcity_integration) { create(:teamcity_integration, :without_callbacks_and_validations) }

    before do
      create(:integration, category: "ci_cd", providable: teamcity_integration, integrable: app)
      allow(teamcity_integration).to receive(:installation).and_return(installation)
    end

    it "returns the transformed list of workflows" do
      allow(installation).to receive(:list_build_configurations)

      teamcity_integration.workflows

      expect(installation).to have_received(:list_build_configurations).with(
        teamcity_integration.project_id,
        TeamcityIntegration::BUILD_CONFIGS_TRANSFORMATIONS
      )
    end

    it "returns empty array when project_id is nil" do
      expect(teamcity_integration.workflows).to eq([])
    end
  end

  describe "#trigger_workflow_run!" do
    let(:app) { create(:app, :android) }
    let(:installation) { instance_double(Installations::Teamcity::Api) }
    let(:teamcity_integration) { create(:teamcity_integration, :without_callbacks_and_validations) }

    before do
      create(:integration, category: "ci_cd", providable: teamcity_integration, integrable: app)
      allow(teamcity_integration).to receive(:installation).and_return(installation)
    end

    it "triggers a build with correct parameters" do
      allow(installation).to receive(:trigger_build).and_return({ci_ref: "123", ci_link: "http://example.com"})
      inputs = {build_version: "1.0.0", version_code: 42}

      teamcity_integration.trigger_workflow_run!("MyProject_Build", "main", inputs, "abc123")

      expect(installation).to have_received(:trigger_build).with(
        "MyProject_Build", "main", inputs, "abc123", TeamcityIntegration::BUILD_RUN_TRANSFORMATIONS
      )
    end
  end

  describe "#cancel_workflow_run!" do
    let(:app) { create(:app, :android) }
    let(:installation) { instance_double(Installations::Teamcity::Api) }
    let(:teamcity_integration) { create(:teamcity_integration, :without_callbacks_and_validations) }

    before do
      create(:integration, category: "ci_cd", providable: teamcity_integration, integrable: app)
      allow(teamcity_integration).to receive(:installation).and_return(installation)
    end

    it "delegates to installation cancel_build" do
      allow(installation).to receive(:cancel_build)
      teamcity_integration.cancel_workflow_run!("123")
      expect(installation).to have_received(:cancel_build).with("123")
    end
  end

  describe "#get_artifact" do
    let(:app) { create(:app, :android) }
    let(:installation) { instance_double(Installations::Teamcity::Api) }
    let(:teamcity_integration) { create(:teamcity_integration, :without_callbacks_and_validations) }

    before do
      create(:integration, category: "ci_cd", providable: teamcity_integration, integrable: app)
      allow(teamcity_integration).to receive(:installation).and_return(installation)
    end

    it "raises when artifact_path is blank" do
      expect {
        teamcity_integration.get_artifact(nil, "*.apk", external_workflow_run_id: "123")
      }.to raise_error(Installations::Error)
    end

    it "raises when artifact metadata is blank" do
      allow(installation).to receive(:get_artifact_metadata).and_return(nil)

      expect {
        teamcity_integration.get_artifact("app.apk", "*.apk", external_workflow_run_id: "123")
      }.to raise_error(Installations::Error)
    end

    it "returns artifact hash with stream" do
      metadata = {name: "app.apk", size_in_bytes: 1024}
      tempfile = Tempfile.new("artifact")
      allow(installation).to receive(:get_artifact_metadata).and_return(metadata)
      allow(installation).to receive(:download_artifact).and_return(tempfile)

      result = teamcity_integration.get_artifact("app.apk", "*.apk", external_workflow_run_id: "123")

      expect(result[:artifact]).to eq(metadata)
      expect(result[:stream]).to be_a(Artifacts::Stream)
      expect(installation).to have_received(:get_artifact_metadata).with("123", "app.apk", TeamcityIntegration::ARTIFACTS_TRANSFORMATIONS)
      expect(installation).to have_received(:download_artifact).with("123", "app.apk")
    ensure
      tempfile&.close
      tempfile&.unlink
    end
  end

  describe "#find_workflow_run" do
    let(:app) { create(:app, :android) }
    let(:installation) { instance_double(Installations::Teamcity::Api) }
    let(:teamcity_integration) { create(:teamcity_integration, :without_callbacks_and_validations) }

    before do
      create(:integration, category: "ci_cd", providable: teamcity_integration, integrable: app)
      allow(teamcity_integration).to receive(:installation).and_return(installation)
    end

    it "delegates to installation find_build" do
      allow(installation).to receive(:find_build).and_return({ci_ref: "123"})
      teamcity_integration.find_workflow_run("MyProject_Build", "main", "abc123")
      expect(installation).to have_received(:find_build).with(
        "MyProject_Build", "main", "abc123", TeamcityIntegration::BUILD_RUN_TRANSFORMATIONS
      )
    end
  end
end
