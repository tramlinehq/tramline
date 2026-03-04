# frozen_string_literal: true

require "rails_helper"

describe Commit::CherryPickJob do
  let(:train) { create(:train, :with_almost_trunk, backmerge_strategy: "cherry_pick") }
  let(:release) { create(:release, :on_track, train:) }
  let(:fmq) { create(:forward_merge, release:) }
  let!(:commit) { create(:commit, release:, forward_merge: fmq) }

  before do
    allow(Triggers::CherryPickPullRequest).to receive(:call).and_return(GitHub::Result.new { true })
  end

  it "calls the cherry-pick trigger" do
    described_class.new.perform(fmq.id)

    expect(Triggers::CherryPickPullRequest).to have_received(:call).with(release, fmq)
  end

  it "sets status to success on success" do
    described_class.new.perform(fmq.id)

    expect(fmq.reload.status).to eq("success")
  end

  it "does nothing if the release is not committable" do
    release.update!(status: "post_release")

    described_class.new.perform(fmq.id)

    expect(Triggers::CherryPickPullRequest).not_to have_received(:call)
  end

  it "does nothing if the forward merge queue entry is not actionable" do
    fmq.update!(status: "success")

    described_class.new.perform(fmq.id)

    expect(Triggers::CherryPickPullRequest).not_to have_received(:call)
  end

  it "sets status to in_progress before calling the trigger" do
    allow(Triggers::CherryPickPullRequest).to receive(:call) do
      expect(fmq.reload.status).to eq("in_progress")
      GitHub::Result.new { true }
    end

    described_class.new.perform(fmq.id)
  end

  context "when cherry-pick fails with a non-retryable error" do
    before do
      fail_result = GitHub::Result.new { raise "Failed to create cherry-pick PR" }
      allow(Triggers::CherryPickPullRequest).to receive(:call).and_return(fail_result)
    end

    it "sets status to failed" do
      described_class.new.perform(fmq.id)

      expect(fmq.reload.status).to eq("failed")
    end
  end

  context "when cherry-pick fails with a retryable error" do
    before do
      retryable_result = GitHub::Result.new { raise Triggers::PullRequest::RetryableMergeError }
      allow(Triggers::CherryPickPullRequest).to receive(:call).and_return(retryable_result)
    end

    it "re-enqueues the job" do
      allow(described_class).to receive_message_chain(:set, :perform_async)

      described_class.new.perform(fmq.id, 0)

      expect(described_class).to have_received(:set)
    end

    it "sets status to failed after max retries" do
      described_class.new.perform(fmq.id, Commit::CherryPickJob::MAX_RETRIES)

      expect(fmq.reload.status).to eq("failed")
    end
  end

  context "when the entry was previously failed" do
    before do
      fmq.update!(status: "failed")
    end

    it "retries the cherry-pick" do
      described_class.new.perform(fmq.id)

      expect(Triggers::CherryPickPullRequest).to have_received(:call)
      expect(fmq.reload.status).to eq("success")
    end
  end
end
