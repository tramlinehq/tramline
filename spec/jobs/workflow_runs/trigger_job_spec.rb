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

    shared_examples "with known error" do |error|
      before do
        allow(workflow_run).to receive(:trigger!).and_raise(error)
      end

      context "when error is #{error.message}" do
        it "changes state of workflow_run to trigger_failed" do
          described_class.new.perform(workflow_run.id)
          expect(workflow_run.reload.status).to eq("trigger_failed")
        end
      end
    end

    include_examples "with known error", Installations::Github::Error.new(
      OpenStruct.new(
        response_body: {message: "Workflow does not have 'workflow_dispatch' trigger"}.to_json
      )
    )
    include_examples "with known error", Installations::Github::Error.new(
      OpenStruct.new(
        response_body: {message: "Required input 'parameter_X' not provided"}.to_json
      )
    )

    context "when error is unknown" do
      before do
        err = Installations::Error.new("Some Error", reason: :unknown_failure)
        allow(workflow_run).to receive(:trigger!).and_raise(err)
      end

      it "does not change state of workflow_run to trigger_failed" do
        begin
          described_class.new.perform(workflow_run.id)
        rescue Installations::Error
          nil
        end

        expect(workflow_run.reload.status).not_to eq("trigger_failed")
      end
    end
  end
end
