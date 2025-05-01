# frozen_string_literal: true

require "rails_helper"

describe WorkflowRuns::TriggerJob do
  let(:workflow_run) { create(:workflow_run, :triggering) }

  before do
    allow_any_instance_of(GithubIntegration).to receive(:trigger_workflow_run!)
  end

  context "when trigger does not cause error" do
    it "initiates the workflow run" do
      described_class.new.perform(workflow_run.id)

      expect(workflow_run.reload.status).to eq("triggered")
    end
  end

  context "when trigger results in error" do
    let(:workflow_run) { create(:workflow_run, :triggering) }

    it "marks the workflow run as trigger_failed when the external unique number is not found" do
      workflow_run.app.update(build_number_managed_internally: false)
      allow_any_instance_of(GithubIntegration).to receive(:trigger_workflow_run!).and_return({unique_number: nil})

      described_class.new.perform(workflow_run.id)

      expect(workflow_run.reload.status).to eq("unavailable")
    end

    shared_examples "with known error" do |error|
      before do
        allow_any_instance_of(GithubIntegration).to receive(:trigger_workflow_run!).and_raise(error)
      end

      context "when error is #{error.message}" do
        it "changes state of workflow_run to trigger_failed" do
          described_class.new.perform(workflow_run.id)
          expect(workflow_run.reload.status).to eq("trigger_failed")
        end
      end
    end

    it_behaves_like "with known error", Installations::Github::Error.new(
      OpenStruct.new(
        response_body: {message: "Workflow does not have 'workflow_dispatch' trigger"}.to_json
      )
    )

    it_behaves_like "with known error", Installations::Github::Error.new(
      OpenStruct.new(
        response_body: {message: "Required input 'parameter_X' not provided"}.to_json
      )
    )

    context "when error is unknown" do
      before do
        err = Installations::Error.new("Some Error", reason: :unknown_failure)
        allow_any_instance_of(GithubIntegration).to receive(:trigger_workflow_run!).and_raise(err)
      end

      it "does not change state of workflow_run to trigger_failed" do
        begin
          described_class.new.perform(workflow_run.id)
        rescue Installations::Error
          nil
        end

        expect(workflow_run.reload.status).to eq("triggering")
        expect(workflow_run.reload.status).not_to eq("trigger_failed")
      end
    end
  end
end
