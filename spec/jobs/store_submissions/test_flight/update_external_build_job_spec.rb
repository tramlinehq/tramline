require "rails_helper"

describe StoreSubmissions::TestFlight::UpdateExternalBuildJob do
  describe "#perform" do
    let(:submission) { create(:test_flight_submission, :submitted_for_review) }

    it "updates external release when submission is ready" do
      allow(submission).to receive(:update_external_release)
      allow(TestFlightSubmission).to receive(:find).and_return(submission)

      described_class.new.perform(submission.id)

      expect(submission).to have_received(:update_external_release)
    end

    it "retries with backoff when submission is not in terminal state" do
      error = TestFlightSubmission::SubmissionNotInTerminalState.new
      allow(submission).to receive(:update_external_release).and_raise(error)
      allow(TestFlightSubmission).to receive(:find).and_return(submission)
      allow(described_class).to receive(:perform_in)

      job = described_class.new
      job.perform(submission.id)

      expect(described_class).to have_received(:perform_in).with(
        300, # 5 minutes in seconds
        kind_of(String),
        {
          "original_exception" => {
            "class" => "TestFlightSubmission::SubmissionNotInTerminalState",
            "message" => "TestFlightSubmission::SubmissionNotInTerminalState"
          },
          "retry_count" => 1
        }
      )
    end

    it "raises error immediately for other errors" do
      error = StandardError.new("Some other error")
      allow(submission).to receive(:update_external_release).and_raise(error)
      allow(TestFlightSubmission).to receive(:find).and_return(submission)

      job = described_class.new
      expect {
        job.perform(submission.id)
      }.to raise_error(StandardError, "Some other error")
    end

    it "respects max retry limit" do
      job = described_class.new
      expect(job.MAX_RETRIES).to eq(2000)
    end

    it "skips processing if submission cannot be finished" do
      submission.update!(status: :finished)
      allow(submission).to receive(:update_external_release)
      allow(TestFlightSubmission).to receive(:find).and_return(submission)

      described_class.new.perform(submission.id)

      expect(submission).not_to have_received(:update_external_release)
    end
  end
end
