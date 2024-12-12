require "rails_helper"

BUILD_NOT_FOUND_CONTEXT = "with build not found error"

describe Releases::FindBuildJob do
  # Shared setup for the test suite
  let(:step_run) { create_deployment_run_tree(:ios, step_run_traits: [:build_ready])[:step_run] }
  let(:build_info) {
    {
      name: "1.2.0",
      build_number: "123",
      status: "READY_FOR_BETA_SUBMISSION",
      added_at: Time.current
    }
  }

  # Create deployment before each test
  before do
    create(:deployment, step: step_run.step, integration: step_run.train.build_channel_integrations.first)
  end

  # Shared context and helpers for build-related tests
  shared_context BUILD_NOT_FOUND_CONTEXT do
    let(:build_not_found_error) {
      Installations::Apple::AppStoreConnect::Error.new({"error" => {"code" => "not_found", "resource" => "build"}})
    }
  end

  # Successful build scenario tests
  describe "successful build retrieval" do
    before do
      allow_any_instance_of(Installations::Apple::AppStoreConnect::Api).to receive(:find_build).and_return(build_info)
    end

    it "updates step run status to deployment started" do
      described_class.new.perform(step_run.id)
      expect(step_run.reload.deployment_started?).to be(true)
    end

    it "calls build_found! and event_stamp! methods" do
      # Disable RSpec VerifiedDoubles warning for this specific line
      # rubocop:disable RSpec/VerifiedDoubles
      step_run_double = instance_double(StepRun,
        id: step_run.id,
        active?: true,
        find_build: double(value!: build_info),
        build_found!: nil,
        event_stamp!: nil,
        build_version: step_run.build_version)
      # rubocop:enable RSpec/VerifiedDoubles

      # Stub the find method to return our double
      allow(StepRun).to receive(:find).and_return(step_run_double)

      job = described_class.new
      job.perform(step_run.id)

      expect(step_run_double).to have_received(:build_found!)
      expect(step_run_double).to have_received(:event_stamp!).with(
        reason: :build_found_in_store,
        kind: :notice,
        data: {version: step_run.build_version}
      )
    end
  end

  # Error and edge case scenarios
  describe "error handling" do
    include_context BUILD_NOT_FOUND_CONTEXT

    context "when build is not found" do
      before do
        allow_any_instance_of(Installations::Apple::AppStoreConnect::Api).to receive(:find_build).and_raise(build_not_found_error)
      end

      it "raises the appropriate exception" do
        expect { described_class.new.perform(step_run.id) }.to raise_error(build_not_found_error)
        expect(step_run.reload.build_ready?).to be(true)
      end

      it "retries job with backoff" do
        job = described_class.new
        allow(job).to receive(:retry_with_backoff)

        expect { job.perform(step_run.id) }.to raise_error(Installations::Error)

        expect(job).to have_received(:retry_with_backoff).with(
          build_not_found_error,
          hash_including(step_run_id: step_run.id)
        )
      end
    end

    context "when retries are exhausted" do
      it "handles exhausted retries correctly" do
        job = described_class.new
        allow(job).to receive(:MAX_RETRIES).and_return(2)
        allow(job).to receive(:on_retries_exhausted)

        # Simulate a persistent error
        build_not_found_error = Installations::Error.new("Build not found", reason: :build_not_found)
        allow_any_instance_of(Installations::Apple::AppStoreConnect::Api).to receive(:find_build).and_raise(build_not_found_error)

        job.perform(step_run.id, retry_count: 3)

        expect(job).to have_received(:on_retries_exhausted).with(hash_including(step_run_id: step_run.id))
      end
    end

    it "re-raises non-build-not-found errors" do
      generic_error = StandardError.new("Unexpected error")
      allow_any_instance_of(Installations::Apple::AppStoreConnect::Api).to receive(:find_build).and_raise(generic_error)

      expect { described_class.new.perform(step_run.id) }.to raise_error(StandardError, "Unexpected error")
    end
  end

  # Skip conditions tests
  describe "skip conditions" do
    it "does nothing if release is not on track" do
      step_run.release_platform_run.update(status: "finished")

      described_class.new.perform(step_run.id)

      expect(step_run.reload.build_ready?).to be(true)
    end

    it "does nothing if the step run is cancelled" do
      step_run.update(status: "cancelled")

      described_class.new.perform(step_run.id)

      expect(step_run.reload.cancelled?).to be(true)
    end
  end

  # Retry mechanism tests
  describe "retry mechanism" do
    include_context BUILD_NOT_FOUND_CONTEXT

    it "increments retry count correctly" do
      # Fully mock the step run to prevent database interactions
      allow(StepRun).to receive(:find).and_return(step_run)
      allow(step_run).to receive(:active?).and_return(true)
      allow(step_run).to receive(:find_build).and_raise(build_not_found_error)

      job = described_class.new
      allow(job).to receive(:retry_with_backoff)

      # Simulate multiple retries
      [1, 2, 3].each do |retry_count|
        job.perform(step_run.id, retry_count: retry_count)
      rescue Installations::Error
        expect(job).to have_received(:retry_with_backoff).with(
          build_not_found_error,
          hash_including(
            step_run_id: step_run.id,
            retry_count: retry_count
          )
        )
      end
    end

    it "calculates backoff values correctly including edge cases" do
      job = described_class.new

      # Test normal cases with default multiplier of 2
      [1, 2, 3, 4].each do |retry_count|
        actual_backoff = job.send(:compute_backoff, retry_count)
        expected_value = [job.backoff_multiplier**retry_count, job.max_backoff_time.to_i].min
        expect(actual_backoff).to eq(expected_value)
      end

      # Test edge cases
      high_retry_counts = [15, 20, 100, 1000, 30000, 600000, 9000000]
      high_retry_counts.each do |retry_count|
        actual_backoff = job.send(:compute_backoff, retry_count)
        expect(actual_backoff).to eq(job.max_backoff_time.to_i)
      end

      # Test that very high retry counts don't exceed max_backoff_time
      expect(job.send(:compute_backoff, 1000)).to eq(job.max_backoff_time.to_i)
    end
  end
end
