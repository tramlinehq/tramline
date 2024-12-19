require "rails_helper"

RSpec.describe Releases::FindWorkflowRun do
  include ActiveJob::TestHelper

  let(:step_run) { create(:step_run) }

  describe "#perform" do
    context "when workflow run is found successfully" do
      it "updates workflow run and transitions state" do
        allow(StepRun).to receive(:find).with(step_run.id).and_return(step_run)
        allow(step_run).to receive(:find_and_update_workflow_run)
        allow(step_run).to receive(:may_ci_start?).and_return(true)
        allow(step_run).to receive(:ci_start!)

        described_class.new.perform(step_run.id)

        expect(StepRun).to have_received(:find).with(step_run.id)
        expect(step_run).to have_received(:find_and_update_workflow_run)
        expect(step_run).to have_received(:may_ci_start?)
        expect(step_run).to have_received(:ci_start!)
      end
    end

    context "when workflow run is not found" do
      let(:workflow_not_found_error) {
        Installations::Error.new("Workflow run not found", reason: :workflow_run_not_found)
      }

      before do
        allow(StepRun).to receive(:find).and_return(step_run)
        allow(step_run).to receive(:find_and_update_workflow_run).and_raise(workflow_not_found_error)
      end

      it "calls retry_with_backoff for workflow_run_not_found error" do
        job = described_class.new
        allow(job).to receive(:retry_with_backoff)

        expect { job.perform(step_run.id) }.to raise_error(workflow_not_found_error)

        expect(job).to have_received(:retry_with_backoff).with(workflow_not_found_error, {
          step_run_id: step_run.id,
          retry_count: 0
        })
      end
    end

    context "when retries are exhausted" do
      it "calls on_retries_exhausted" do
        job = described_class.new
        retry_args = {step_run_id: step_run.id, retry_count: job.MAX_RETRIES + 1}

        allow(StepRun).to receive(:find).with(step_run.id).and_return(step_run)
        allow(step_run).to receive(:may_ci_unavailable?).and_return(true)
        allow(step_run).to receive(:ci_unavailable!)
        allow(step_run).to receive(:event_stamp!)

        job.perform(step_run.id, retry_args)

        expect(step_run).to have_received(:ci_unavailable!)
        expect(step_run).to have_received(:event_stamp!).with(
          reason: :ci_workflow_unavailable,
          kind: :error,
          data: {}
        )
      end
    end

    context "when an unexpected error occurs" do
      let(:unexpected_error) { StandardError.new("Unexpected error") }

      it "raises the error" do
        allow(StepRun).to receive(:find).and_return(step_run)
        allow(step_run).to receive(:find_and_update_workflow_run).and_raise(unexpected_error)

        expect { described_class.new.perform(step_run.id) }.to raise_error(unexpected_error)
      end
    end
  end

  describe "#on_retries_exhausted" do
    it "transitions step run to ci_unavailable and logs event" do
      allow(StepRun).to receive(:find).with(step_run.id).and_return(step_run)
      allow(step_run).to receive(:may_ci_unavailable?).and_return(true)
      allow(step_run).to receive(:ci_unavailable!)
      allow(step_run).to receive(:event_stamp!)

      described_class.new.on_retries_exhausted({step_run_id: step_run.id})

      expect(StepRun).to have_received(:find).with(step_run.id)
      expect(step_run).to have_received(:may_ci_unavailable?)
      expect(step_run).to have_received(:ci_unavailable!)
      expect(step_run).to have_received(:event_stamp!).with(
        reason: :ci_workflow_unavailable,
        kind: :error,
        data: {}
      )
    end
  end
end
