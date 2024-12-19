require "rails_helper"

RSpec.describe Deployments::GoogleFirebase::UpdateUploadStatusJob do
  let(:deployment_run) { create(:deployment_run) }
  let(:op_name) { "operations/123" }

  describe "#perform" do
    it "calls update_upload_status! with correct parameters" do
      allow(Deployments::GoogleFirebase::Release).to receive(:update_upload_status!)

      described_class.new.perform(deployment_run.id, op_name)

      expect(Deployments::GoogleFirebase::Release)
        .to have_received(:update_upload_status!)
        .with(deployment_run, op_name)
    end

    it "retries with backoff when UploadNotComplete error occurs" do
      error = Deployments::GoogleFirebase::Release::UploadNotComplete.new
      allow(Deployments::GoogleFirebase::Release).to receive(:update_upload_status!).and_raise(error)
      allow(described_class).to receive(:perform_in)

      job = described_class.new
      job.perform(deployment_run.id, op_name)

      expect(described_class).to have_received(:perform_in).with(
        120, # 2 minutes in seconds
        deployment_run.id,
        op_name,
        hash_including(
          "retry_count" => 1,
          "step_run_id" => deployment_run.id,
          "original_exception" => hash_including(
            "class" => "Deployments::GoogleFirebase::Release::UploadNotComplete"
          )
        )
      )
    end

    it "stops retrying for other errors" do
      error = StandardError.new("Some other error")
      allow(Deployments::GoogleFirebase::Release).to receive(:update_upload_status!).and_raise(error)
      allow(Rails.logger).to receive(:error)

      job = described_class.new
      expect {
        job.perform(deployment_run.id, op_name)
      }.to raise_error("Retries exhausted")
    end

    it "respects max retry limit" do
      job = described_class.new
      expect(job.MAX_RETRIES).to eq(5)
    end

    it "skips processing for non-firebase integrations" do
      non_firebase_run = create(:deployment_run)
      allow(DeploymentRun).to receive(:find).and_return(non_firebase_run)
      allow(non_firebase_run).to receive(:google_firebase_integration?).and_return(false)
      allow(Deployments::GoogleFirebase::Release).to receive(:update_upload_status!)

      described_class.new.perform(non_firebase_run.id, op_name)

      expect(Deployments::GoogleFirebase::Release).not_to have_received(:update_upload_status!)
    end
  end
end
