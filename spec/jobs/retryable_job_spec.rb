require "rails_helper"

RSpec.describe RetryableJob, type: :model do
  let(:job) { instance_spy(TestRetryableJob) }
  let(:exception) { StandardError.new("Test error") }

  # Mock the test job class as a constant stub
  before do
    stub_const("TestRetryableJob", Class.new do
      include Sidekiq::Job
      include RetryableJob

      def perform(step_run_id, context = {})
        retry_count = context.is_a?(Hash) ? context["retry_count"] || 0 : 0

        # Simulate a failure condition
        raise "Simulated failure" if retry_count < MAX_RETRIES

        # Successful execution
        true
      end

      def on_retries_exhausted(context)
        handle_retries_exhausted(context)
      end
    end)
  end

  describe "#retry_with_backoff" do
    context "when retry count is within limit" do
      it "re-enqueues the job with increasing backoff" do
        allow(TestRetryableJob).to receive(:perform_in)

        job = TestRetryableJob.new
        job.retry_with_backoff(exception, {})

        expect(TestRetryableJob).to have_received(:perform_in).with(
          2,  # Default backoff value
          an_instance_of(String),  # UUID
          hash_including("retry_count" => 1)
        )
      end

      it "computes correct backoff times" do
        # Test multiple backoff computations
        job = TestRetryableJob.new
        backoff_times = [
          job.send(:compute_backoff, 1),
          job.send(:compute_backoff, 2),
          job.send(:compute_backoff, 3),
          job.send(:compute_backoff, 4),
          job.send(:compute_backoff, 5)
        ]

        expect(backoff_times).to eq([2, 4, 8, 16, 32])
      end
    end

    context "when retry count exceeds maximum" do
      it "calls handle_retries_exhausted" do
        job = TestRetryableJob.new
        allow(job).to receive(:handle_retries_exhausted)

        job.retry_with_backoff(exception, retry_count: TestRetryableJob.MAX_RETRIES)

        expect(job).to have_received(:handle_retries_exhausted).with(
          hash_including(retry_count: TestRetryableJob.MAX_RETRIES + 1)
        )
      end
    end

    context "with retry context" do
      it "handles context with step_run_id" do
        allow(TestRetryableJob).to receive(:perform_in)

        job = TestRetryableJob.new
        job.retry_with_backoff(exception, step_run_id: "test_id")

        expect(TestRetryableJob).to have_received(:perform_in).with(
          2,  # Default backoff value
          "test_id",
          hash_including("retry_count" => 1, "step_run_id" => "test_id")
        )
      end
    end

    context "when retry_count is zero" do
      it "re-enqueues the job with initial backoff" do
        allow(TestRetryableJob).to receive(:perform_in)

        job = TestRetryableJob.new
        job.retry_with_backoff(exception, retry_count: 0)

        expect(TestRetryableJob).to have_received(:perform_in).with(
          2, # Initial backoff value
          an_instance_of(String),
          hash_including("retry_count" => 1)
        )
      end
    end

    context "when retry context is nil" do
      it "initializes context properly and re-enqueues" do
        allow(TestRetryableJob).to receive(:perform_in)

        job = TestRetryableJob.new
        job.retry_with_backoff(exception, nil)

        expect(TestRetryableJob).to have_received(:perform_in).with(
          2,
          an_instance_of(String),
          hash_including("retry_count" => 1)
        )
      end
    end

    context "when exception has no backtrace" do
      it "handles nil backtrace gracefully" do
        allow(TestRetryableJob).to receive(:perform_in)
        exception = StandardError.new("No backtrace")
        allow(exception).to receive(:backtrace).and_return(nil)

        job = TestRetryableJob.new
        expect { job.retry_with_backoff(exception) }.not_to raise_error
      end
    end
  end

  describe "#compute_backoff" do
    it "respects max_backoff_time" do
      job = TestRetryableJob.new
      job.class.max_backoff_time = 1.minute
      job.class.backoff_multiplier = 10

      expect(job.send(:compute_backoff, 5)).to eq(1.minute.to_i)
    end
  end

  describe "MAX_RETRIES configuration" do
    it "has correct default value" do
      expect(TestRetryableJob.MAX_RETRIES).to eq(8)
    end

    it "allows override of MAX_RETRIES" do
      TestRetryableJob.MAX_RETRIES = 12
      expect(TestRetryableJob.MAX_RETRIES).to eq(12)
    end
  end
end
