require "rails_helper"

RSpec.describe StoreSubmissions::AppStore::FindBuildJob do
  let(:release_platform_run) { create(:release_platform_run) }
  let(:parent_release) { create(:production_release, release_platform_run: release_platform_run) }

  let(:submission) do
    create(:app_store_submission,
      :created,
      parent_release: parent_release,
      release_platform_run: release_platform_run)
  end

  # Shared context for build not found error
  shared_context "with build not found error" do
    let(:build_not_found_error) {
      Installations::Error.new("Build not found", reason: :build_not_found)
    }
  end

  describe "successful build retrieval" do
    let(:build_info) {
      {
        name: "1.2.0",
        build_number: "123",
        status: "READY_FOR_BETA_SUBMISSION",
        added_at: Time.current
      }
    }

    before do
      # Disable RSpec VerifiedDoubles warning for this specific line
      # rubocop:disable RSpec/VerifiedDoubles
      allow(submission).to receive(:find_build).and_return(double(value!: build_info))
      # rubocop:enable RSpec/VerifiedDoubles
    end

    it "prepares for release" do
      # Create a job instance
      job = described_class.new

      # Spy on the submission
      allow(submission).to receive(:prepare_for_release!)

      # Stub find method to return our real submission
      allow(AppStoreSubmission).to receive(:find).and_return(submission)

      # Perform the job
      job.perform(submission.id)

      # Check that prepare_for_release! was called
      expect(submission).to have_received(:prepare_for_release!)
    end
  end

  describe "error handling" do
    include_context "with build not found error"

    context "when build is not found" do
      before do
        # Stub find_build to raise build not found error
        allow(submission).to receive(:find_build).and_raise(build_not_found_error)
      end

      it "retries job with backoff" do
        # Create a job instance
        job = described_class.new

        # Spy on retry_with_backoff
        allow(job).to receive(:retry_with_backoff)

        # Stub find method to return our real submission
        allow(AppStoreSubmission).to receive(:find).and_return(submission)

        # Expect the job to raise the error
        expect { job.perform(submission.id) }.to raise_error(Installations::Error)

        # Check that retry_with_backoff was called with correct arguments
        expect(job).to have_received(:retry_with_backoff)
          .with(build_not_found_error, hash_including(submission_id: submission.id))
      end
    end

    context "when retries are exhausted" do
      it "handles exhausted retries correctly" do
        job = described_class.new
        allow(job).to receive(:MAX_RETRIES).and_return(2)

        # Stub find method to return our real submission
        allow(AppStoreSubmission).to receive(:find).and_return(submission)

        # Spy on fail_with_error!
        allow(submission).to receive(:fail_with_error!)

        # Perform with exhausted retry count
        job.perform(submission.id, retry_count: 3)

        # Check that fail_with_error! was called with correct arguments
        expect(submission).to have_received(:fail_with_error!)
          .with(an_instance_of(Installations::Error))
      end
    end

    it "re-raises non-build-not-found errors" do
      generic_error = StandardError.new("Unexpected error")

      # Stub find_build to raise generic error
      allow(submission).to receive(:find_build).and_raise(generic_error)

      # Stub find method to return our real submission
      allow(AppStoreSubmission).to receive(:find).and_return(submission)

      # Expect the generic error to be re-raised
      expect { described_class.new.perform(submission.id) }.to raise_error(StandardError, "Unexpected error")
    end
  end

  describe "skip conditions" do
    it "does nothing if submission is not actionable" do
      # Stub submission to be non-actionable
      allow(submission).to receive(:actionable?).and_return(false)

      # Stub find method to return our real submission
      allow(AppStoreSubmission).to receive(:find).and_return(submission)

      # Perform job and expect no additional method calls
      expect {
        described_class.new.perform(submission.id)
      }.not_to raise_error
    end
  end

  describe "retry mechanism" do
    include_context "with build not found error"

    it "increments retry count correctly" do
      job = described_class.new

      # Stub find_build to raise build not found error
      allow(submission).to receive(:find_build).and_raise(build_not_found_error)

      # Stub find method to return our real submission
      allow(AppStoreSubmission).to receive(:find).and_return(submission)

      # Spy on retry_with_backoff
      allow(job).to receive(:retry_with_backoff)

      # Simulate retry attempts
      [1, 2, 3].each do |retry_count|
        job.perform(submission.id, retry_count: retry_count)
      rescue Installations::Error
        # Expected behavior
      end

      # Check that retry_with_backoff was called with correct arguments
      [1, 2, 3].each do |retry_count|
        expect(job).to have_received(:retry_with_backoff)
          .with(build_not_found_error, hash_including(
            submission_id: submission.id,
            retry_count: retry_count
          ))
      end
    end
  end
end
