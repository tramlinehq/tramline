# frozen_string_literal: true

require "rails_helper"

describe "BitriseIntegration" do
  describe "#workflows" do
    let(:app) { create(:app, :android, id: "a6f392f6-e92c-4f00-a2e6-a5db7abfb0e0") }
    let(:installation) { instance_double(Installations::Bitrise::Api) }
    let(:bitrise_integration) { create(:bitrise_integration, :without_callbacks_and_validations) }

    before do
      Flipper.disable_actor(:custom_bitrise_pipelines, app)
      create(:integration, category: "ci_cd", providable: bitrise_integration, integrable: app)
    end

    context "when using workflows" do
      before do
        allow(bitrise_integration).to receive(:installation).and_return(installation)
      end

      it "returns the transformed list of workflows" do
        allow(installation).to receive(:list_workflows)

        bitrise_integration.workflows

        expect(installation).to have_received(:list_workflows).with(bitrise_integration.project, BitriseIntegration::WORKFLOWS_TRANSFORMATIONS)
      end
    end

    context "when using custom pipelines" do
      before do
        Flipper.enable_actor(:custom_bitrise_pipelines, app)
        allow(bitrise_integration).to receive(:installation).and_return(installation)
        mock_file = instance_double(StringIO)
        allow(URI).to(
          receive(:open)
            .with(
              "https://storage.googleapis.com/tramline-public-assets/custom_bitrise_pipelines.yml?ignoreCache=0",
              "Cache-Control" => "max-age=0",
              :read_timeout => 10
            )
        ).and_return(mock_file)
        allow(mock_file).to receive(:read).and_return(File.read("spec/fixtures/bitrise/custom_pipelines.yml"))
      end

      it "returns the transformed list of workflows" do
        expected_output =
          [
            {
              "id" => "build-and-deploy-pipeline",
              "name" => "build-and-deploy-pipeline"
            },
            {
              "id" => "primary",
              "name" => "primary"
            }
          ]
        expect(bitrise_integration.workflows).to eq(expected_output)
      end
    end
  end
end
