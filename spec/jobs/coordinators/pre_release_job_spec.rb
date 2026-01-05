# frozen_string_literal: true

require "rails_helper"

describe Coordinators::PreReleaseJob do
  let(:release_branch) { "v1.0.0" }

  describe "#perform" do
    let(:release) { create(:release, :created) }

    before do
      allow(release).to receive_messages(release_branch:, train: create(:train, branching_strategy: "almost_trunk"))
    end

    it "handles hotfix with existing branch by signaling commits have landed" do
      latest_commit = {sha: "123"}
      allow(Release).to receive(:find).with(release.id).and_return(release)
      allow(release).to receive(:hotfix_with_existing_branch?).and_return(true)
      allow(release).to receive(:latest_commit_hash).with(sha_only: false).and_return(latest_commit)
      allow(described_class::Signal).to receive(:commits_have_landed!)

      described_class.new.perform(release.id)

      expect(described_class::Signal).to have_received(:commits_have_landed!).with(release, latest_commit, [])
    end

    it "starts pre-release phase and calls the appropriate handler" do
      allow(release).to receive(:hotfix_with_existing_branch?).and_return(false)
      allow(Coordinators::PreRelease::AlmostTrunk).to receive(:call).and_return(GitHub::Result.new)

      described_class.new.perform(release.id)

      expect(release.reload.status).to eq("pre_release_started")
    end
  end

  describe "retry functionality" do
    let(:release) { create(:release, :pre_release_started) }

    before do
      allow(release).to receive_messages(release_branch:, train: create(:train, branching_strategy: "almost_trunk"))
    end

    describe ".retryable_failure?" do
      it "returns true for retryable branch create errors" do
        error = Triggers::Branch::RetryableBranchCreateError.new("branch create failed")
        expect(described_class.retryable_failure?(error)).to be(true)
      end

      it "returns false for other Triggers::Errors" do
        error = Triggers::Errors.new("other error")
        expect(described_class.retryable_failure?(error)).to be(false)
      end

      it "returns false for non-Triggers errors" do
        error = StandardError.new("some error")
        expect(described_class.retryable_failure?(error)).to be(false)
      end
    end

    describe ".trigger_failure?" do
      it "returns true for Triggers::Errors" do
        error = Triggers::Errors.new("some error")
        expect(described_class.trigger_failure?(error)).to be(true)
      end

      it "returns false for non-Triggers errors" do
        error = StandardError.new("some error")
        expect(described_class.trigger_failure?(error)).to be(false)
      end
    end

    describe ".existing_branch?" do
      it "returns true for BranchAlreadyExistsError" do
        error = Triggers::Branch::BranchAlreadyExistsError.new("branch already exists")
        expect(described_class.existing_branch?(error)).to be(true)
      end

      it "returns false for other Triggers::Errors" do
        error = Triggers::Errors.new("other error")
        expect(described_class.existing_branch?(error)).to be(false)
      end

      it "returns false for RetryableBranchCreateError" do
        error = Triggers::Branch::RetryableBranchCreateError.new("branch create failed")
        expect(described_class.existing_branch?(error)).to be(false)
      end

      it "returns false for non-Triggers errors" do
        error = StandardError.new("some error")
        expect(described_class.existing_branch?(error)).to be(false)
      end
    end

    describe ".signal_commits_have_landed!" do
      it "fetches latest commit and signals commits have landed" do
        latest_commit = {sha: "abc123", message: "test commit"}
        allow(release).to receive(:latest_commit_hash).with(sha_only: false).and_return(latest_commit)
        allow(described_class::Signal).to receive(:commits_have_landed!)

        described_class.signal_commits_have_landed!(release)

        expect(described_class::Signal).to have_received(:commits_have_landed!).with(release, latest_commit, [])
      end
    end

    describe ".mark_failed!" do
      before do
        allow(described_class).to receive(:elog)
      end

      it "marks release as failed and logs the error" do
        error = Triggers::Errors.new("test error")

        described_class.mark_failed!(release, error)

        expect(described_class).to have_received(:elog).with(error, level: :warn)
        expect(release.reload.status).to eq("pre_release_failed")
      end
    end

    describe "sidekiq retry callbacks" do
      let(:msg) { {"args" => [release.id]} }

      before do
        allow(release).to receive_messages(release_branch:, train: create(:train, branching_strategy: "almost_trunk"))
      end

      it "retries with backoff for retryable failures" do
        error = Triggers::Branch::RetryableBranchCreateError.new("branch create failed")
        expect(described_class.new.sidekiq_retry_in_block.call(0, error, msg)).to eq(1.minute.to_i)
        expect(described_class.new.sidekiq_retry_in_block.call(1, error, msg)).to eq(1.minute.to_i)
      end

      it "kills job immediately for trigger failures" do
        allow(described_class).to receive(:mark_failed!)

        error = Triggers::Errors.new("some error")
        expect(described_class.new.sidekiq_retry_in_block.call(0, error, msg)).to eq(:kill)
        expect(described_class).to have_received(:mark_failed!).with(release, error)
      end

      it "kills job immediately for other errors" do
        error = StandardError.new("some error")
        expect(described_class.new.sidekiq_retry_in_block.call(0, error, msg)).to eq(:kill)
      end

      it "signals commits have landed and kills job for existing branch errors" do
        latest_commit = {sha: "abc123", message: "test commit"}
        allow(Release).to receive(:find).with(release.id).and_return(release)
        allow(release).to receive(:latest_commit_hash).with(sha_only: false).and_return(latest_commit)
        allow(described_class::Signal).to receive(:commits_have_landed!)

        error = Triggers::Branch::BranchAlreadyExistsError.new("branch already exists")
        result = described_class.new.sidekiq_retry_in_block.call(0, error, msg)

        expect(result).to eq(:kill)
        expect(described_class::Signal).to have_received(:commits_have_landed!).with(release, latest_commit, [])
      end

      it "marks job as failed when retries are exhausted for retryable failures" do
        allow(described_class).to receive(:mark_failed!)

        error = Triggers::Branch::RetryableBranchCreateError.new("branch create failed")
        described_class.new.sidekiq_retries_exhausted_block.call(msg, error)
        expect(described_class).to have_received(:mark_failed!).with(release, error)
      end
    end
  end
end
