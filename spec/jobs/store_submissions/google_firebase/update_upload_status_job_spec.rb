require "rails_helper"

RSpec.describe StoreSubmissions::GoogleFirebase::UpdateUploadStatusJob do
  let(:submission) { create(:google_firebase_submission, :created) }
  let(:op_name) { "operations/123" }

  describe "#perform" do
    it "calls update_upload_status! with correct parameters" do
      allow(submission).to receive(:update_upload_status!)
      allow(GoogleFirebaseSubmission).to receive(:find).and_return(submission)

      described_class.new.perform(submission.id, op_name)

      expect(submission).to have_received(:update_upload_status!).with(op_name)
    end

    it "retries with backoff when UploadNotComplete error occurs" do
      error = GoogleFirebaseSubmission::UploadNotComplete.new
      allow(submission).to receive(:update_upload_status!).and_raise(error)
      allow(GoogleFirebaseSubmission).to receive(:find).and_return(submission)
      allow(described_class).to receive(:perform_in)

      job = described_class.new
      job.perform(submission.id, op_name)

      expect(described_class).to have_received(:perform_in).with(
        120,
        kind_of(String), # Use kind_of matcher for the ID
        op_name,
        {
          "original_exception" => {
            "class" => "GoogleFirebaseSubmission::UploadNotComplete",
            "message" => "GoogleFirebaseSubmission::UploadNotComplete"
          },
          "retry_count" => 1
        }
      )
    end

    it "raises error immediately for other errors" do
      error = StandardError.new("Some other error")
      allow(submission).to receive(:update_upload_status!).and_raise(error)
      allow(GoogleFirebaseSubmission).to receive(:find).and_return(submission)

      job = described_class.new
      expect {
        job.perform(submission.id, op_name)
      }.to raise_error(StandardError, "Some other error")
    end

    it "respects max retry limit" do
      job = described_class.new
      expect(job.MAX_RETRIES).to eq(5)
    end

    it "skips processing if submission cannot be prepared" do
      submission.update!(status: :preparing)
      allow(submission).to receive(:update_upload_status!)
      allow(GoogleFirebaseSubmission).to receive(:find).and_return(submission)

      described_class.new.perform(submission.id, op_name)

      expect(submission).not_to have_received(:update_upload_status!)
    end
  end
end
