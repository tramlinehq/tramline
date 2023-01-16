require "rails_helper"

describe Releases::UploadArtifact, type: :job do
  describe "#perform" do
    let(:artifacts_url) { Faker::Internet.url }
    let(:artifact_stream) { Rack::Test::UploadedFile.new("spec/fixtures/storage/test_artifact.aab.zip", "application/zip") }

    before do
      allow_any_instance_of(GithubIntegration).to receive(:download_stream).and_return(artifact_stream)
      allow(Triggers::Deployment).to receive(:call)
    end

    it "creates build artifact, triggers deployment and marks run as deployment started" do
      step_run = create(:releases_step_run, :build_ready)

      described_class.new.perform(step_run.id, artifacts_url)

      expect(Triggers::Deployment).to have_received(:call).with(step_run: step_run.reload).once
      expect(step_run.build_artifact).to be_present
      expect(step_run.reload.deployment_started?).to be(true)
    end

    context "when auto-triggering multiple deployments" do
      let(:step) { create(:releases_step, :with_deployment) }

      before do
        create_list(:deployment, 2, step: step)
      end

      it "triggers multiple deployments when the step has run previously" do
        old_step_run = create(:releases_step_run, :success, step: step, scheduled_at: 1.minute.ago)

        step.deployments.each do |deployment|
          create(:deployment_run, deployment: deployment, step_run: old_step_run)
        end

        new_step_run = create(:releases_step_run, :build_ready, step: step, train_run: old_step_run.train_run)

        described_class.new.perform(new_step_run.id, artifacts_url)

        expect(Triggers::Deployment).to have_received(:call).with(step_run: new_step_run.reload, deployment: step.deployments[0]).once
        expect(Triggers::Deployment).to have_received(:call).with(step_run: new_step_run.reload, deployment: step.deployments[1]).once
        expect(Triggers::Deployment).to have_received(:call).with(step_run: new_step_run.reload, deployment: step.deployments[2]).once
      end

      it "triggers only the deployment that have run before" do
        old_step_run = create(:releases_step_run, :deployment_started, step: step, scheduled_at: 1.minute.ago)
        create(:deployment_run, deployment: step.deployments[0], step_run: old_step_run)
        create(:deployment_run, deployment: step.deployments[1], step_run: old_step_run)

        new_step_run = create(:releases_step_run, :build_ready, step: step, train_run: old_step_run.train_run)

        described_class.new.perform(new_step_run.id, artifacts_url)

        expect(Triggers::Deployment).to have_received(:call).with(step_run: new_step_run.reload, deployment: step.deployments[0]).once
        expect(Triggers::Deployment).to have_received(:call).with(step_run: new_step_run.reload, deployment: step.deployments[1]).once
        expect(Triggers::Deployment).not_to have_received(:call).with(step_run: new_step_run.reload, deployment: step.deployments[2])
      end

      it "triggers all deployments that have run in the last deployed run" do
        older_step_run = create(:releases_step_run, :deployment_started, step: step, scheduled_at: 2.minutes.ago)
        create(:deployment_run, deployment: step.deployments[0], step_run: older_step_run)
        create(:deployment_run, deployment: step.deployments[1], step_run: older_step_run)

        _old_failed_step_run = create(:releases_step_run, :ci_workflow_failed, step: step,
          train_run: older_step_run.train_run, scheduled_at: 1.minute.ago)

        new_step_run = create(:releases_step_run, :build_ready, step: step, train_run: older_step_run.train_run)

        described_class.new.perform(new_step_run.id, artifacts_url)

        expect(Triggers::Deployment).to have_received(:call).with(step_run: new_step_run.reload, deployment: step.deployments[0]).once
        expect(Triggers::Deployment).to have_received(:call).with(step_run: new_step_run.reload, deployment: step.deployments[1]).once
        expect(Triggers::Deployment).not_to have_received(:call).with(step_run: new_step_run.reload, deployment: step.deployments[2])
      end

      it "triggers all deployments that have run before even if they had failed" do
        older_step_run = create(:releases_step_run, :deployment_failed, step: step, scheduled_at: 2.minutes.ago)
        create(:deployment_run, :released, deployment: step.deployments[0], step_run: older_step_run)
        create(:deployment_run, :failed, deployment: step.deployments[1], step_run: older_step_run)

        new_step_run = create(:releases_step_run, :build_ready, step: step, train_run: older_step_run.train_run)

        described_class.new.perform(new_step_run.id, artifacts_url)

        expect(Triggers::Deployment).to have_received(:call).with(step_run: new_step_run.reload, deployment: step.deployments[0]).once
        expect(Triggers::Deployment).to have_received(:call).with(step_run: new_step_run.reload, deployment: step.deployments[1]).once
        expect(Triggers::Deployment).not_to have_received(:call).with(step_run: new_step_run.reload, deployment: step.deployments[2])
      end
    end
  end
end
