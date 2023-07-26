require "rails_helper"

describe Releases::FindBuildJob do
  describe "#perform" do
    let(:step_run) { create_step_run_for_ios(:build_ready) }
    let(:build_info) {
      {
        name: "1.2.0",
        build_number: "123",
        status: "READY_FOR_BETA_SUBMISSION",
        added_at: Time.current
      }
    }

    before do
      create(:deployment, step: step_run.step, integration: step_run.train.build_channel_integrations.first)
    end

    it "finds the build for the step run and updates step run status" do
      allow_any_instance_of(Installations::Apple::AppStoreConnect::Api).to receive(:find_build).and_return(build_info)

      described_class.new.perform(step_run.id)

      expect(step_run.reload.deployment_started?).to be(true)
    end

    it "raises appropriate exception if build is not found" do
      build_not_found_error = Installations::Apple::AppStoreConnect::Error.new({"error" => {"code" => "not_found", "resource" => "build"}})
      allow_any_instance_of(Installations::Apple::AppStoreConnect::Api).to receive(:find_build).and_raise(build_not_found_error)

      expect { described_class.new.perform(step_run.id) }.to raise_error(build_not_found_error)

      expect(step_run.reload.build_ready?).to be(true)
    end

    it "does nothing if release is not on track" do
      step_run.release_platform_run.update(status: "finished")

      described_class.new.perform(step_run.id)

      expect(step_run.reload.build_ready?).to be(true)
    end

    it "does nothing if teh step run is cancelled" do
      step_run.update(status: "cancelled")

      described_class.new.perform(step_run.id)

      expect(step_run.reload.cancelled?).to be(true)
    end
  end
end
