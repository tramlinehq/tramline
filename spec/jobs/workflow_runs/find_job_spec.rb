# frozen_string_literal: true

require "rails_helper"

describe WorkflowRuns::FindJob do
  let(:workflow_run) { create(:workflow_run, :triggered) }

  context "when build number is managed externally" do
    before do
      workflow_run.app.update(build_number_managed_internally: false)
    end

    it "marks the workflow run as trigger_failed when the external unique number is not found" do
      allow_any_instance_of(GithubIntegration).to receive(:find_workflow_run).and_return({unique_number: nil})

      described_class.new.perform(workflow_run.id)

      expect(workflow_run.reload.status).to eq("unavailable")
    end
  end
end
