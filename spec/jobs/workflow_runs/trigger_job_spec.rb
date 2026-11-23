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
        it "raises the error and leaves workflow_run in triggering state" do
          expect {
            described_class.new.perform(workflow_run.id)
          }.to raise_error(Installations::Github::Error)

          expect(workflow_run.reload.status).to eq("triggering")
        end
      end
    end

    it_behaves_like "with known error", Installations::Github::Error.new(OpenStruct.new(response_body: {message: "Required input 'parameter_X' not provided"}.to_json))

    it_behaves_like "with known error", Installations::Github::Error.new(OpenStruct.new(response_body: {message: "Workflow does not have 'workflow_dispatch' trigger"}.to_json))

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

  describe "retry logic simulation" do
    let(:msg) { {"args" => [workflow_run.id]} }

    describe "sidekiq_retry_in behavior" do
      it "returns backoff time for retryable trigger failures" do
        error = Installations::Error.new("Not runnable", reason: :workflow_run_not_runnable)

        result = described_class.sidekiq_retry_in_block.call(2, error, msg)

        expect(result).to be_a(Integer)
        expect(result).to be > 0
      end

      it "kills job immediately for non-retryable trigger failures" do
        error = Installations::Error.new("Parameter not provided", reason: :workflow_parameter_not_provided)
        allow(described_class).to receive(:mark_failed!)

        result = described_class.sidekiq_retry_in_block.call(1, error, msg)

        expect(result).to eq(:kill)
        expect(described_class).to have_received(:mark_failed!).with(msg, error)
      end

      it "marks the run trigger_failed and kills the job for errors it does not recognise" do
        error = Installations::Github::Error.new(OpenStruct.new(response_body: {message: "Not Found"}.to_json))
        allow(PassportJob).to receive(:perform_async)

        result = described_class.sidekiq_retry_in_block.call(1, error, msg)

        expect(result).to eq(:kill)
        expect(workflow_run.reload.status).to eq("trigger_failed")
        expect(PassportJob).to have_received(:perform_async)
          .with(workflow_run.id, "WorkflowRun", hash_including(reason: "trigger_failed", kind: "error"))
      end

      it "marks the run trigger_failed for errors that are not installation errors" do
        result = described_class.sidekiq_retry_in_block.call(1, StandardError.new("boom"), msg)

        expect(result).to eq(:kill)
        expect(workflow_run.reload.status).to eq("trigger_failed")
      end
    end

    describe "sidekiq_retries_exhausted behavior" do
      it "marks job as failed when retryable trigger failure exhausts retries" do
        error = Installations::Error.new("Not runnable", reason: :workflow_run_not_runnable)
        allow(described_class).to receive(:mark_failed!)

        described_class.sidekiq_retries_exhausted_block.call(msg, error)

        expect(described_class).to have_received(:mark_failed!).with(msg, error)
      end

      it "does nothing when non-retryable error exhausts retries" do
        error = Installations::Error.new("Parameter not provided", reason: :workflow_parameter_not_provided)
        allow(described_class).to receive(:mark_failed!)

        described_class.sidekiq_retries_exhausted_block.call(msg, error)

        expect(described_class).not_to have_received(:mark_failed!)
      end
    end

    describe "mark_failed! behavior" do
      it "marks workflow run as trigger_failed with error" do
        error = Installations::Error.new("Test error", reason: :workflow_parameter_not_provided)

        described_class.mark_failed!(msg, error)

        expect(workflow_run.reload.status).to eq("trigger_failed")
      end

      it "leaves a run that has moved on alone" do
        workflow_run.update!(status: "started")

        described_class.mark_failed!(msg, StandardError.new("late failure"))

        expect(workflow_run.reload.status).to eq("started")
      end
    end

    describe "error classification" do
      it "identifies retryable trigger failures" do
        error = Installations::Error.new("Not runnable", reason: :workflow_run_not_runnable)

        expect(described_class.retryable_trigger_failure?(error)).to be true
      end

      it "does not treat other errors as retryable" do
        expect(described_class.retryable_trigger_failure?(Installations::Error.new("x", reason: :workflow_parameter_not_provided))).to be false
        expect(described_class.retryable_trigger_failure?(StandardError.new("x"))).to be false
      end
    end
  end
end
