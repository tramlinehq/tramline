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
      repo_integration = instance_double(Installations::Github::Api)
      allow(Installations::Github::Api).to receive(:new).and_return(repo_integration)
      allow(repo_integration).to receive(:create_tag!)
      run = create_deployment_run_tree(:ios, :rollout_started, :with_external_release, deployment_traits: [:with_production_channel], step_traits: [:release])[:deployment_run]
      live_release = release_info.merge(status: "READY_FOR_SALE", build_number: run.build_number)
      allow_any_instance_of(Installations::Apple::AppStoreConnect::Api).to receive(:find_live_release).and_return(live_release)

      described_class.new.perform(run.id)

      expect(run.reload.released?).to be(true)
    end

    it "raises error if release is not live" do
      run = create_deployment_run_tree(:ios, :rollout_started, :with_external_release, deployment_traits: [:with_production_channel], step_traits: [:release])[:deployment_run]
      allow_any_instance_of(Installations::Apple::AppStoreConnect::Api).to receive(:find_live_release).and_return(release_info)

      expect { described_class.new.perform(run.id) }.to raise_error(Deployments::AppStoreConnect::Release::ReleaseNotFullyLive)

      expect(run.reload.released?).to be(false)
    end

    it "schedules retry with correct backoff for ReleaseNotFullyLive error" do
      run = create_deployment_run_tree(:ios, :rollout_started, :with_external_release,
        deployment_traits: [:with_production_channel],
        step_traits: [:release])[:deployment_run]

      error = Deployments::AppStoreConnect::Release::ReleaseNotFullyLive.new
      allow(Deployments::AppStoreConnect::Release).to receive(:track_live_release_status).and_raise(error)
      allow(described_class).to receive(:perform_in)

      job = described_class.new
      expect {
        job.perform(run.id)
      }.to raise_error(Deployments::AppStoreConnect::Release::ReleaseNotFullyLive)

      expect(described_class).to have_received(:perform_in).with(
        300, # 5 minutes in seconds
        run.id,
        hash_including(
          "retry_count" => 1,
          "step_run_id" => run.id,
          "original_exception" => hash_including(
            "class" => "Deployments::AppStoreConnect::Release::ReleaseNotFullyLive"
          )
        )
      )
    end

    it "raises error and stops retrying for unexpected errors" do
      run = create_deployment_run_tree(:ios, :rollout_started, :with_external_release,
        deployment_traits: [:with_production_channel],
        step_traits: [:release])[:deployment_run]

      error = StandardError.new("Unexpected error")
      allow(Deployments::AppStoreConnect::Release).to receive(:track_live_release_status).and_raise(error)
      allow(described_class).to receive(:perform_in)

      job = described_class.new
      expect {
        job.perform(run.id)
      }.to raise_error("Retries exhausted")
    end
  end

  describe "retry behavior" do
    let(:run) { create_deployment_run_tree(:ios, :rollout_started, :with_external_release, deployment_traits: [:with_production_channel], step_traits: [:release])[:deployment_run] }

    it "retries with correct backoff when ReleaseNotFullyLive occurs" do
      error = Deployments::AppStoreConnect::Release::ReleaseNotFullyLive.new
      allow(Deployments::AppStoreConnect::Release).to receive(:track_live_release_status).and_raise(error)
      allow(described_class).to receive(:perform_in)

      job = described_class.new
      expect {
        job.perform(run.id)
      }.to raise_error(Deployments::AppStoreConnect::Release::ReleaseNotFullyLive)

      expect(described_class).to have_received(:perform_in).with(
        300, # 5 minutes in seconds
        run.id,
        hash_including(
          "retry_count" => 1,
          "step_run_id" => run.id,
          "original_exception" => hash_including(
            "class" => "Deployments::AppStoreConnect::Release::ReleaseNotFullyLive"
          )
        )
      )
    end

    it "stops retrying for other errors" do
      error = StandardError.new("Unexpected error")
      allow(Deployments::AppStoreConnect::Release).to receive(:track_live_release_status).and_raise(error)
      allow(Rails.logger).to receive(:error)

      job = described_class.new
      expect {
        job.perform(run.id)
      }.to raise_error("Retries exhausted")
    end

    it "respects max retry limit" do
      job = described_class.new
      expect(job.MAX_RETRIES).to eq(6000)
    end
  end
end
