# frozen_string_literal: true

require "rails_helper"

describe Deployments::AppStoreConnect::Release do
  describe ".kickoff!" do
    it "does nothing if not allowed" do
      run = create(:deployment_run)
      expect(described_class.kickoff!(run)).to be_nil
    end

    context "when production channel" do
      it "starts preparing the release" do
        deployment = create(:deployment, :with_app_store, :with_production_channel)
        run = create(:deployment_run, deployment:)
        job = Deployments::AppStoreConnect::PrepareForReleaseJob
        allow(job).to receive(:perform_later)

        described_class.kickoff!(run)

        expect(job).to have_received(:perform_later).with(run.id).once
      end
    end

    context "when not production channel" do
      it "starts adding to beta group when testflight" do
        deployment = create(:deployment, :with_step, :with_app_store)
        run = create(:deployment_run, deployment:)
        job = Deployments::AppStoreConnect::TestFlightReleaseJob
        allow(job).to receive(:perform_later)

        described_class.kickoff!(run)

        expect(job).to have_received(:perform_later).with(run.id).once
      end
    end
  end

  describe ".to_test_flight!" do
    it "does nothing if not allowed"
    it "adds build to beta group"
    it "marks the deployment run as submitted"
    it "marks the deployment run as failed when failure"
    it "adds the reason of failure to deployment run"
  end

  describe ".prepare_for_release!" do
    it "does nothing if not allowed"
    it "prepares the release"
    it "marks the deployment run as prepared release"
    it "marks the deployment run as failed when failure"
    it "adds the reason of failure to deployment run"
  end

  describe ".submit_for_review!" do
    it "does nothing if not allowed"
    it "submits the release"
    it "marks the deployment run as submitted"
    it "marks the deployment run as failed when failure"
    it "adds the reason of failure to deployment run"
  end

  describe ".update_external_release" do
    it "does nothing if not allowed"

    context "when testflight" do
      it "finds build"
      it "updates external release"
      it "marks deployment run as completed"
      it "marks the deployment run as failed when failure"
      it "adds the reason of failure to deployment run"
    end

    context "when production" do
      it "finds release"
      it "updates external release"
      it "marks deployment run as ready to release"
      it "marks the deployment run as failed when failure"
      it "adds the reason of failure to deployment run"
    end
  end

  describe ".start_release!" do
    it "does nothing if not allowed"
    it "starts the release"
    it "creates staged rollout if staged rollout enabled"
    it "marks the deployment run as failed when failure"
    it "adds the reason of failure to deployment run"
  end

  describe ".track_live_release_status" do
    it "does nothing if not allowed"
    it "finds the live release"
    it "raises error if release is not fully live"

    context "when staged rollout" do
      it "updates staged rollout"
      it "completes the run if staged rollout has finished"
    end

    context "when no staged rollout" do
      it "completes the run"
    end

    it "marks the deployment run as failed when failure"
    it "adds the reason of failure to deployment run"
  end
end
