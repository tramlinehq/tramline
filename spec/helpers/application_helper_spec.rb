require "rails_helper"

describe ApplicationHelper do
  describe "#workflow_select_options" do
    let(:ci_actions) do
      [
        {id: "workflow_1", name: "Build and Deploy"},
        {id: "workflow_2", name: "Release Build"}
      ]
    end

    def workflow(identifier:, name:)
      Config::Workflow.new(kind: "release_candidate", identifier:, name:)
    end

    it "maps the provider list to [name, id] pairs" do
      current = workflow(identifier: "workflow_1", name: "Build and Deploy")

      expect(helper.workflow_select_options(ci_actions, current))
        .to eq([["Build and Deploy", "workflow_1"], ["Release Build", "workflow_2"]])
    end

    context "when the provider list is empty (transient API miss)" do
      it "still includes the configured workflow so it round-trips on save" do
        current = workflow(identifier: "configured_wf", name: "Configured Workflow")

        expect(helper.workflow_select_options([], current))
          .to eq([["Configured Workflow", "configured_wf"]])
      end

      it "falls back to the identifier when the configured workflow has no name" do
        current = workflow(identifier: "configured_wf", name: nil)

        expect(helper.workflow_select_options([], current))
          .to eq([["configured_wf", "configured_wf"]])
      end
    end

    context "when the configured workflow is missing from the provider list" do
      it "prepends it without dropping the provider options" do
        current = workflow(identifier: "configured_wf", name: "Configured Workflow")

        expect(helper.workflow_select_options(ci_actions, current))
          .to eq([
            ["Configured Workflow", "configured_wf"],
            ["Build and Deploy", "workflow_1"],
            ["Release Build", "workflow_2"]
          ])
      end
    end

    context "when the configured workflow is already in the provider list" do
      it "does not duplicate it" do
        current = workflow(identifier: "workflow_2", name: "Release Build")

        expect(helper.workflow_select_options(ci_actions, current))
          .to eq([["Build and Deploy", "workflow_1"], ["Release Build", "workflow_2"]])
      end
    end

    context "when there is no configured workflow" do
      it "returns just the provider options" do
        expect(helper.workflow_select_options(ci_actions, nil))
          .to eq([["Build and Deploy", "workflow_1"], ["Release Build", "workflow_2"]])
      end
    end
  end
end
