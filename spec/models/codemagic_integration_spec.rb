# frozen_string_literal: true

require "rails_helper"

describe "CodemagicIntegration" do
  describe "#workflows" do
    let(:app) { create(:app, :android, id: "a6f392f6-e92c-4f00-a2e6-a5db7abfb0e0") }
    let(:installation) { instance_double(Installations::Codemagic::Api) }
    let(:codemagic_integration) { create(:codemagic_integration, :without_callbacks_and_validations) }

    before do
      create(:integration, category: "ci_cd", providable: codemagic_integration, integrable: app)
      allow(codemagic_integration).to receive(:installation).and_return(installation)
    end

    it "returns the transformed list of workflows" do
      allow(installation).to receive(:list_workflows)

      codemagic_integration.workflows

      expect(installation).to have_received(:list_workflows).with(codemagic_integration.project, CodemagicIntegration::WORKFLOWS_TRANSFORMATIONS)
    end
  end

  describe "#list_apps" do
    let(:codemagic_integration) { create(:codemagic_integration, :without_callbacks_and_validations) }
    let(:installation) { instance_double(Installations::Codemagic::Api) }

    before do
      allow(codemagic_integration).to receive(:installation).and_return(installation)
    end

    it "returns the transformed list of apps" do
      allow(installation).to receive(:list_apps)

      codemagic_integration.list_apps

      expect(installation).to have_received(:list_apps).with(CodemagicIntegration::APPS_TRANSFORMATIONS)
    end
  end
end
