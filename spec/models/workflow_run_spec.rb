# frozen_string_literal: true

require "rails_helper"

describe WorkflowRun do
  it "has a valid factory" do
    expect(create(:workflow_run)).to be_valid
  end

  describe "#trigger!" do
    let(:ci_ref) { Faker::Number.number(digits: 6).to_s }
    let(:ci_link) { Faker::Internet.url }
    let(:number) { Faker::Number.number(digits: 3).to_s }
    let(:api_double) { instance_double(Installations::Google::PlayDeveloper::Api) }
    let(:workflow_run) { create(:workflow_run, :triggering) }
    let(:unique_number) { (workflow_run.app.build_number + 1).to_s }

    before do
      allow_any_instance_of(GithubIntegration).to receive(:trigger_workflow_run!)
      allow_any_instance_of(GooglePlayStoreIntegration).to receive(:installation).and_return(api_double)
      allow(api_double).to receive(:find_latest_build_number).and_return(123)
    end

    context "when workflow triggered (github)" do
      before do
        allow_any_instance_of(GithubIntegration).to receive(:trigger_workflow_run!).and_return({ci_ref:, ci_link:, number:, unique_number:})
      end

      it "transitions state to started" do
        workflow_run.trigger!

        expect(workflow_run.started?).to be(true)
      end

      it "updates external metadata" do
        workflow_run.trigger!
        workflow_run.reload

        expect(workflow_run.external_id).to eq(ci_ref)
        expect(workflow_run.external_url).to eq(ci_link)
        expect(workflow_run.external_number).to eq(number)
      end

      context "when use build number from workflow is disabled" do
        it "updates build number" do
          expect(workflow_run.build.build_number).to be_nil
          workflow_run.trigger!
          expect(workflow_run.build.build_number).not_to be_empty
        end
      end

      context "when use build number from workflow is enabled" do
        before do
          workflow_run.app.update(build_number_managed_internally: false)
        end

        it "updates build number" do
          expect(workflow_run.build.build_number).to be_nil

          workflow_run.trigger!

          expect(workflow_run.build.build_number).to eq(unique_number)
          expect(workflow_run.app.build_number.to_s).to eq(unique_number)
        end

        it "fails the workflow run if external unique number is not available" do
          allow_any_instance_of(GithubIntegration).to receive(:trigger_workflow_run!).and_return({ci_ref:, ci_link:, number:, unique_number: nil})

          expect {
            workflow_run.trigger!
          }.to raise_error(WorkflowRun::ExternalUniqueNumberNotFound)
        end
      end
    end
  end
end
