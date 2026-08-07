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

  describe "lazily-assigned build number (trigger defers, poll resolves)" do
    let(:ci_ref) { Faker::Number.number(digits: 6).to_s }
    let(:ci_link) { Faker::Internet.url }
    let(:workflow_run) { create(:workflow_run, :triggering) }
    let(:teamcity) { create(:teamcity_integration, :without_callbacks_and_validations, project_config: {"id" => "Project"}) }

    before do
      create(:integration, category: "ci_cd", providable: teamcity, integrable: workflow_run.app)
      allow(workflow_run).to receive(:ci_cd_provider).and_return(teamcity)
      workflow_run.app.update!(build_number_managed_internally: false)
    end

    it "does not raise at trigger when the provider has not assigned a number yet" do
      allow(teamcity).to receive(:trigger_workflow_run!).and_return({ci_ref:, ci_link:, number: nil, unique_number: nil})

      expect { workflow_run.trigger! }.not_to raise_error

      workflow_run.reload
      expect(workflow_run.external_id).to eq(ci_ref)
      expect(workflow_run.external_unique_number).to be_nil
      expect(workflow_run.build.build_number).to be_nil
    end

    it "resolves the deferred build number on a later poll" do
      allow(teamcity).to receive(:trigger_workflow_run!).and_return({ci_ref:, ci_link:, number: nil, unique_number: nil})
      workflow_run.trigger!
      expect(workflow_run.reload.external_unique_number).to be_nil

      resolved = (workflow_run.app.build_number + 1).to_s
      workflow_run.apply_build_number!(resolved, resolved) # simulates update_build_number_from_poll!

      workflow_run.reload
      expect(workflow_run.external_unique_number).to eq(resolved)
      expect(workflow_run.build.build_number).to eq(resolved)
      expect(workflow_run.app.reload.build_number.to_s).to eq(resolved)
    end

    it "skips non-numeric values so an unresolved template is not persisted" do
      expect {
        workflow_run.apply_build_number!("%dep.Other.system.build.number%", "%dep.Other.system.build.number%")
      }.not_to change { workflow_run.reload.external_unique_number }
      expect(workflow_run.build.build_number).to be_nil
    end

    it "bumps the app counter only once across repeated poll ticks" do
      resolved = (workflow_run.app.build_number + 1).to_s
      workflow_run.apply_build_number!(resolved, resolved)

      expect {
        workflow_run.apply_build_number!(resolved, resolved)
      }.not_to change { workflow_run.app.reload.build_number }
    end
  end
end
