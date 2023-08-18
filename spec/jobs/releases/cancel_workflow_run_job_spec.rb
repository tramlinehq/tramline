require "rails_helper"

describe Releases::CancelWorkflowRunJob do
  describe "#perform" do
    let(:ci_cd_mock_provider) { instance_double(GithubIntegration) }

    before do
      allow_any_instance_of(StepRun).to receive(:ci_cd_provider).and_return(ci_cd_mock_provider)
    end

    it "cancels CI workflow if present" do
      step_run = create(:step_run, :cancelling, ci_ref: "ci_ref")
      allow(ci_cd_mock_provider).to receive(:cancel_workflow_run!)
      described_class.new.perform(step_run.id)

      expect(ci_cd_mock_provider).to have_received(:cancel_workflow_run!)
    end

    it "raises an exception if CI workflow is not present" do
      step_run = create(:step_run, :cancelling, ci_ref: nil)
      expect {
        described_class.new.perform(step_run.id)
      }.to raise_error(Releases::CancelWorkflowRunJob::WorkflowRunNotFound)
    end
  end
end
