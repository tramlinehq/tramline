require "rails_helper"

describe Releases::AppStoreConnect::FindBuildJob do
  describe "#perform" do
    let(:app) { create(:app, :ios) }
    let(:train) { create(:releases_train, app: app) }
    let(:step) { create(:releases_step, :with_deployment, train: train) }
    let(:step_run) { create(:releases_step_run, :build_ready, step: step) }
    let(:build_info) {
      {
        name: "1.2.0",
        build_number: "123",
        status: "READY_FOR_BETA_SUBMISSION",
        added_at: Time.current
      }
    }

    before do
      create(:integration, :with_app_store, app: app)
    end

    it "finds the build for the step run and updates step run status" do
      allow_any_instance_of(Installations::Apple::AppStoreConnect::Api).to receive(:find_build).and_return(build_info)

      described_class.new.perform(step_run.id)

      expect(step_run.reload.deployment_started?).to be(true)
    end

    it "raises appropriate exception if build is not found" do
      build_not_found_error = Installations::Errors::BuildNotFoundInStore
      allow_any_instance_of(Installations::Apple::AppStoreConnect::Api).to receive(:find_build).and_raise(build_not_found_error)

      expect { described_class.new.perform(step_run.id) }.to raise_error(build_not_found_error)

      expect(step_run.reload.build_ready?).to be(true)
    end

    it "does nothing if release is not on track" do
      step_run.train_run.update(status: "finished")

      described_class.new.perform(step_run.id)

      expect(step_run.reload.build_ready?).to be(true)
    end
  end
end
