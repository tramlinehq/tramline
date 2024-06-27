# frozen_string_literal: true

require "rails_helper"

describe WorkflowRun do
  it "has a valid factory" do
    expect(create(:workflow_run)).to be_valid
  end

  describe "#trigger_external_run!" do
    let(:ci_ref) { Faker::Lorem.word }
    let(:ci_link) { Faker::Internet.url }
    let(:number) { Faker::Number.number(digits: 3).to_s }
    let(:api_double) { instance_double(Installations::Google::PlayDeveloper::Api) }
    let(:workflow_run) { create(:workflow_run) }

    before do
      allow_any_instance_of(GithubIntegration).to receive(:trigger_workflow_run!)
      allow_any_instance_of(GooglePlayStoreIntegration).to receive(:installation).and_return(api_double)
      allow(api_double).to receive(:find_latest_build_number).and_return(123)
    end

    context "when workflow not found" do
      before do
        allow_any_instance_of(GithubIntegration).to receive(:trigger_workflow_run!).and_return(nil)
      end

      it "transitions state to triggered" do
        workflow_run.trigger_external_run!

        expect(workflow_run.triggered?).to be(true)
      end

      it "triggers find workflow run" do
        allow(WorkflowRuns::FindJob).to receive(:perform_async)

        workflow_run.trigger_external_run!

        expect(WorkflowRuns::FindJob).to have_received(:perform_async).with(workflow_run.id).once
      end
    end

    context "when workflow found" do
      before do
        allow_any_instance_of(GithubIntegration).to receive(:trigger_workflow_run!).and_return({ci_ref:, ci_link:, number:})
      end

      it "transitions state to started" do
        workflow_run.trigger_external_run!

        expect(workflow_run.started?).to be(true)
      end

      it "updates external metadata" do
        workflow_run.trigger_external_run!
        workflow_run.reload

        expect(workflow_run.external_id).to eq(ci_ref)
        expect(workflow_run.external_url).to eq(ci_link)
        expect(workflow_run.external_number).to eq(number)
      end
    end

    it "stamps an event" do
      id = workflow_run.id
      name = workflow_run.class.name
      allow(PassportJob).to receive(:perform_later)

      workflow_run.trigger_external_run!

      expect(PassportJob).to have_received(:perform_later).with(id, name, hash_including(reason: :ci_triggered)).once
    end

    it "updates build number" do
      allow(Releases::FindWorkflowRun).to receive(:perform_async)

      expect(workflow_run.build_number).to be_nil
      workflow_run.trigger_external_run!
      expect(workflow_run.build_number).not_to be_empty
    end
  end
end
