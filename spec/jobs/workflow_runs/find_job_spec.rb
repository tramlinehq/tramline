require "rails_helper"

describe WorkflowRuns::FindJob do
  describe "#perform" do
    let(:workflow_run) { create(:workflow_run, :triggering) }

    it "finds and updates external workflow run" do
      allow(workflow_run).to receive(:find_and_update_external)
      allow(workflow_run).to receive(:may_found?).and_return(true)
      allow(workflow_run).to receive(:found!)
      allow(WorkflowRun).to receive(:find).and_return(workflow_run)

      described_class.new.perform(workflow_run.id)

      expect(workflow_run).to have_received(:find_and_update_external)
      expect(workflow_run).to have_received(:found!)
    end

    it "retries with backoff when workflow run is not found" do
      error = Installations::Error.new("Workflow run not found", reason: :workflow_run_not_found)
      allow(workflow_run).to receive(:find_and_update_external).and_raise(error)
      allow(WorkflowRun).to receive(:find).and_return(workflow_run)
      allow(described_class).to receive(:perform_in)

      job = described_class.new
      job.perform(workflow_run.id)

      expect(described_class).to have_received(:perform_in).with(
        60,
        kind_of(String),
        {
          "original_exception" => {
            "class" => "Installations::Error",
            "message" => "Workflow run not found"
          },
          "retry_count" => 1
        }
      )
    end

    it "marks workflow run as unavailable when retries are exhausted" do
      workflow_run = create(:workflow_run, :triggered)
      job = described_class.new
      error = Installations::Error.new("Workflow run not found", reason: :workflow_run_not_found)
      context = {
        workflow_run_id: workflow_run.id,
        last_exception: error,
        retry_count: job.MAX_RETRIES + 1
      }

      allow(WorkflowRun).to receive(:find).and_return(workflow_run)
      job.handle_retries_exhausted(context)

      expect(workflow_run.reload.unavailable?).to be true
    end

    it "raises error immediately for other errors" do
      error = StandardError.new("Some other error")
      allow(workflow_run).to receive(:find_and_update_external).and_raise(error)
      allow(WorkflowRun).to receive(:find).and_return(workflow_run)

      job = described_class.new
      expect {
        job.perform(workflow_run.id)
      }.to raise_error(StandardError, "Some other error")
    end

    it "respects max retry limit" do
      job = described_class.new
      expect(job.MAX_RETRIES).to eq(25)
    end
  end
end
