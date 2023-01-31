require "rails_helper"

describe Deployments::AppStoreConnect::UpdateExternalBuildJob do
  describe "#perform" do
    context "when non app store deployment" do
      let(:play_store_deployment_run) { create(:deployment_run, :submitted, :with_google_play_store) }

      it "does nothing if deployment is not for app store" do
        described_class.new.perform(play_store_deployment_run.id)

        expect(play_store_deployment_run.reload.submitted?).to be(true)
      end
    end

    context "when app store deployment" do
      let(:app_store_deployment_run) { create_deployment_run_for_ios(:submitted) }
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
      let(:failure_build_info) { base_build_info.merge(status: "BETA_REJECTED") }

      it "does nothing if the train run is no longer on track" do
        app_store_deployment_run.release.update(status: "finished")

        described_class.new.perform(app_store_deployment_run.id)

        expect(app_store_deployment_run.reload.submitted?).to be(true)
      end

      it "creates external build for the deployment run" do
        allow_any_instance_of(Installations::Apple::AppStoreConnect::Api).to receive(:find_build).and_return(initial_build_info)

        expect(app_store_deployment_run.external_build).not_to be_present
        described_class.new.perform(app_store_deployment_run.id)

        expect(app_store_deployment_run.reload.submitted?).to be(true)
        expect(app_store_deployment_run.reload.external_build).to be_present
      end

      it "updates external build for the deployment run" do
        app_store_deployment_run.create_external_build(initial_build_info)
        allow_any_instance_of(Installations::Apple::AppStoreConnect::Api).to receive(:find_build).and_return(in_progress_build_info)

        described_class.new.perform(app_store_deployment_run.id)

        expect(app_store_deployment_run.reload.submitted?).to be(true)
        expect(app_store_deployment_run.external_build.reload.status).to eq(in_progress_build_info[:status])
      end

      it "marks deployment run as released when build is successful" do
        app_store_deployment_run.create_external_build(in_progress_build_info)
        allow_any_instance_of(Installations::Apple::AppStoreConnect::Api).to receive(:find_build).and_return(success_build_info)

        described_class.new.perform(app_store_deployment_run.id)

        expect(app_store_deployment_run.reload.released?).to be(true)
        expect(app_store_deployment_run.external_build.reload.status).to eq(success_build_info[:status])
      end

      it "marks deployment run as failed when build is a failure" do
        app_store_deployment_run.create_external_build(in_progress_build_info)
        allow_any_instance_of(Installations::Apple::AppStoreConnect::Api).to receive(:find_build).and_return(failure_build_info)

        described_class.new.perform(app_store_deployment_run.id)

        expect(app_store_deployment_run.reload.failed?).to be(true)
        expect(app_store_deployment_run.external_build.reload.status).to eq(failure_build_info[:status])
      end

      it "enqueues another job with increased attempt if build is still in progress" do
        app_store_deployment_run.create_external_build(initial_build_info)
        allow_any_instance_of(Installations::Apple::AppStoreConnect::Api).to receive(:find_build).and_return(in_progress_build_info)

        expect(described_class).to receive_message_chain("set.perform_later").with(
          app_store_deployment_run.id,
          attempt: 2
        )
        described_class.new.perform(app_store_deployment_run.id)
      end
    end
  end
end
