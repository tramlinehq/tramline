require "rails_helper"

describe Deployments::AppStoreConnect::UpdateExternalReleaseJob do
  describe "#perform" do
    context "when non app store deployment" do
      let(:play_store_deployment_run) { create_deployment_run_tree(:android, :submitted_for_review)[:deployment_run] }

      it "does nothing if deployment is not for app store" do
        described_class.new.perform(play_store_deployment_run.id)
        expect(play_store_deployment_run.reload.submitted_for_review?).to be(true)
      end
    end

    context "when app store deployment" do
      let(:app_store_deployment_run) { create_deployment_run_tree(:ios, :submitted_for_review)[:deployment_run] }
      let(:base_build_info) {
        {
          name: "1.2.0",
          build_number: "123",
          added_at: 1.day.ago
        }
      }
      let(:initial_build_info) { base_build_info.merge(status: "WAITING_FOR_BETA_REVIEW") }
      let(:in_progress_build_info) { base_build_info.merge(status: "IN_BETA_REVIEW") }
      let(:success_build_info) { base_build_info.merge(status: "BETA_APPROVED") }
      let(:rejected_build_info) { base_build_info.merge(status: "BETA_REJECTED") }
      let(:failure_build_info) { base_build_info.merge(status: "PROCESSING_EXCEPTION") }

      it "does nothing if the train run is no longer on track" do
        app_store_deployment_run.release_platform_run.update(status: "finished")

        described_class.new.perform(app_store_deployment_run.id)

        expect(app_store_deployment_run.reload.submitted_for_review?).to be(true)
      end

      it "creates external build for the deployment run" do
        allow_any_instance_of(Installations::Apple::AppStoreConnect::Api)
          .to receive(:find_build).and_return(initial_build_info)

        expect(app_store_deployment_run.external_release).not_to be_present
        expect { described_class.new.perform(app_store_deployment_run.id) }
          .to raise_error(Deployments::AppStoreConnect::Release::ExternalReleaseNotInTerminalState)

        expect(app_store_deployment_run.reload.submitted_for_review?).to be(true)
        expect(app_store_deployment_run.reload.external_release).to be_present
      end

      it "updates external build for the deployment run" do
        app_store_deployment_run.create_external_release(initial_build_info)
        allow_any_instance_of(Installations::Apple::AppStoreConnect::Api)
          .to receive(:find_build).and_return(in_progress_build_info)

        expect { described_class.new.perform(app_store_deployment_run.id) }
          .to raise_error(Deployments::AppStoreConnect::Release::ExternalReleaseNotInTerminalState)

        expect(app_store_deployment_run.reload.submitted_for_review?).to be(true)
        expect(app_store_deployment_run.external_release.reload.status).to eq(in_progress_build_info[:status])
      end

      it "marks deployment run as released when build is successful" do
        app_store_deployment_run.create_external_release(in_progress_build_info)
        allow_any_instance_of(Installations::Apple::AppStoreConnect::Api)
          .to receive(:find_build).and_return(success_build_info)

        described_class.new.perform(app_store_deployment_run.id)

        expect(app_store_deployment_run.reload.released?).to be(true)
        expect(app_store_deployment_run.external_release.reload.status).to eq(success_build_info[:status])
      end

      it "marks deployment run as review failed when build is rejected" do
        app_store_deployment_run.create_external_release(in_progress_build_info)
        allow_any_instance_of(Installations::Apple::AppStoreConnect::Api)
          .to receive(:find_build).and_return(rejected_build_info)

        expect { described_class.new.perform(app_store_deployment_run.id) }
          .to raise_error(Deployments::AppStoreConnect::Release::ExternalReleaseNotInTerminalState)

        expect(app_store_deployment_run.reload.review_failed?).to be(true)
        expect(app_store_deployment_run.external_release.reload.status).to eq(rejected_build_info[:status])
      end

      it "marks deployment run as failed when build is a failure" do
        app_store_deployment_run.create_external_release(in_progress_build_info)
        allow_any_instance_of(Installations::Apple::AppStoreConnect::Api)
          .to receive(:find_build).and_return(failure_build_info)

        described_class.new.perform(app_store_deployment_run.id)

        expect(app_store_deployment_run.reload.failed?).to be(true)
        expect(app_store_deployment_run.external_release.reload.status).to eq(failure_build_info[:status])
      end
    end

    describe "retry behavior" do
      let(:app_store_deployment_run) { create_deployment_run_tree(:ios, :submitted_for_review)[:deployment_run] }

      it "retries with correct backoff when ExternalReleaseNotInTerminalState occurs" do
        error = Deployments::AppStoreConnect::Release::ExternalReleaseNotInTerminalState.new
        allow(Deployments::AppStoreConnect::Release).to receive(:update_external_release).and_raise(error)
        allow(described_class).to receive(:perform_in)

        job = described_class.new
        expect {
          job.perform(app_store_deployment_run.id)
        }.to raise_error(Deployments::AppStoreConnect::Release::ExternalReleaseNotInTerminalState)

        expect(described_class).to have_received(:perform_in).with(
          300, # 5 minutes in seconds
          app_store_deployment_run.id,
          hash_including(
            "retry_count" => 1,
            "step_run_id" => app_store_deployment_run.id,
            "original_exception" => hash_including(
              "class" => "Deployments::AppStoreConnect::Release::ExternalReleaseNotInTerminalState"
            )
          )
        )
      end

      it "stops retrying for other errors" do
        error = StandardError.new("Unexpected error")
        allow(Deployments::AppStoreConnect::Release).to receive(:update_external_release).and_raise(error)
        allow(Rails.logger).to receive(:error)

        job = described_class.new
        expect {
          job.perform(app_store_deployment_run.id)
        }.to raise_error("Retries exhausted")
      end

      it "respects max retry limit" do
        job = described_class.new
        expect(job.MAX_RETRIES).to eq(2000)
      end
    end
  end
end
