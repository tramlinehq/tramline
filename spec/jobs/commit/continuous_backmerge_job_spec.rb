# frozen_string_literal: true

require "rails_helper"

describe Commit::ContinuousBackmergeJob do
  let(:train) { create(:train, :with_almost_trunk, backmerge_strategy: "continuous") }
  let(:release) { create(:release, :on_track, train:) }
  let!(:first_commit) { create(:commit, release:) }

  before do
    allow(Triggers::PatchPullRequest).to receive(:call).and_return(GitHub::Result.new { true })
  end

  it "does nothing if the train is not configured for backmerge" do
    train.update!(backmerge_strategy: "on_finalize")
    commit = create(:commit, release:)

    described_class.new.perform(commit.id)

    expect(Triggers::PatchPullRequest).not_to have_received(:call)
  end

  context "when single_pr_backmerge_for_multi_commit_push is configured" do
    it "creates a patch PR when it is off and is_head_commit is irrelevant" do
      Flipper.disable_actor(:single_pr_backmerge_for_multi_commit_push, train.organization)
      commit = create(:commit, release:)

      described_class.new.perform(commit.id, is_head_commit: [true, false].sample)

      expect(Triggers::PatchPullRequest).to have_received(:call)
    end

    it "does not create patch PR when it is on and it is not a head commit" do
      Flipper.enable_actor(:single_pr_backmerge_for_multi_commit_push, train.organization)
      commit = create(:commit, release:)

      described_class.new.perform(commit.id, is_head_commit: false)

      expect(Triggers::PatchPullRequest).not_to have_received(:call)
    end

    it "creates patch PR when it is on and it is a head commit" do
      Flipper.enable_actor(:single_pr_backmerge_for_multi_commit_push, train.organization)
      commit = create(:commit, release:)

      described_class.new.perform(commit.id, is_head_commit: true)

      expect(Triggers::PatchPullRequest).to have_received(:call)
    end
  end

  it "does not create a patch PR it there is only one commit" do
    described_class.new.perform(first_commit.id)
    expect(Triggers::PatchPullRequest).not_to have_received(:call)
  end

  it "creates a patch PR for the commit" do
    commit = create(:commit, release:)
    described_class.new.perform(commit.id)

    expect(Triggers::PatchPullRequest).to have_received(:call)
  end

  context "when patch or backmerge PR fails" do
    before do
      fail_result = GitHub::Result.new { raise "Failed to create patch pull request" }
      allow(Triggers::PatchPullRequest).to receive(:call).and_return(fail_result)
    end

    it "marks the commit as backmerge failed" do
      commit = create(:commit, release:)
      described_class.new.perform(commit.id)

      expect(commit.reload.backmerge_failure).to be(true)
    end

    it "notifies about the backmerge failure" do
      commit = create(:commit, release:)
      allow(commit).to receive(:notify!)
      described_class.new.perform(commit.id)


      expect(commit).to have_received(:notify!).with("Backmerge to the working branch failed", :backmerge_failed, commit.notification_params)
    end
  end
end
