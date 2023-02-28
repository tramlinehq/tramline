require "rails_helper"

describe Deployments::AppStoreConnect::FindLiveReleaseJob do
  describe "#perform" do
    let(:release_info) {
      {
        name: "1.2.0",
        build_number: "123",
        phased_release_day: 0
      }
    }

    it "marks something if release is live" do
      run = create_deployment_run_for_ios(:started, deployment_trait: :with_production_channel, step_trait: :release)
      live_release = release_info.merge(status: "READY_FOR_SALE", build_number: run.build_number)
      allow_any_instance_of(Installations::Apple::AppStoreConnect::Api).to receive(:find_live_release).and_return(live_release)

      described_class.new.perform(run.id)

      expect(run.reload.released?).to be(true)
    end

    it "enqueues another job with increased attempt if release is not live yet" do
      run = create_deployment_run_for_ios(:started, deployment_trait: :with_production_channel, step_trait: :release)
      not_live_release = release_info.merge(status: "IN_BETA_REVIEW")
      allow_any_instance_of(Installations::Apple::AppStoreConnect::Api).to receive(:find_live_release).and_return(not_live_release)

      expect(described_class).to receive_message_chain("set.perform_later").with(
        run.id,
        attempt: 2
      )

      described_class.new.perform(run.id)
      expect(run.reload.released?).not_to be(true)
    end
  end
end
