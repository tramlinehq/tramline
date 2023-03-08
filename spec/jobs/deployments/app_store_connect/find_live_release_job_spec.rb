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
      run = create_deployment_run_for_ios(:started, deployment_traits: [:with_production_channel], step_trait: :release)
      run.create_external_release
      live_release = release_info.merge(status: "READY_FOR_SALE", build_number: run.build_number)
      allow_any_instance_of(Installations::Apple::AppStoreConnect::Api).to receive(:find_live_release).and_return(live_release)

      described_class.new.perform(run.id)

      expect(run.reload.released?).to be(true)
    end

    it "raises error if release is not live" do
      run = create_deployment_run_for_ios(:started, deployment_traits: [:with_production_channel], step_trait: :release)
      run.create_external_release
      allow_any_instance_of(Installations::Apple::AppStoreConnect::Api).to receive(:find_live_release).and_return(release_info)

      expect { described_class.new.perform(run.id) }.to raise_error(Deployments::AppStoreConnect::Release::ReleaseNotFullyLive)

      expect(run.reload.released?).to be(false)
    end

    it "retries if release is not live yet" do
      expect(
        described_class.sidekiq_retry_in_block.call(1, Deployments::AppStoreConnect::Release::ReleaseNotFullyLive.new)
      ).to be >= 600.seconds
    end

    it "does not retry if there are unexpected errors" do
      expect(
        described_class.sidekiq_retry_in_block.call(1, StandardError.new)
      ).to be(:kill)
    end
  end
end
