# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorkflowRuns::TriggerJob do
  let(:workflow_run) { create(:workflow_run, :triggering) }

  before do
    allow(WorkflowRun).to receive(:find).and_return(workflow_run)
  end

  context "when trigger does not cause error" do
    before do
      allow(workflow_run).to receive(:trigger!)
    end

    it "triggers successfully" do
      described_class.new.perform(workflow_run.id)
      expect(workflow_run).to have_received(:trigger!)
    end
  end

  context "when trigger results in error" do
    let(:workflow_run) { create(:workflow_run, :triggering) }

    before do
      allow(workflow_run).to receive(:trigger!).and_raise(Installations::Error, "Some error")
    end

    it "changes state of workflow_run to failed" do
      described_class.new.perform(workflow_run.id)
      expect(workflow_run.reload.status).to eq("failed")
    end
  end
end
