# frozen_string_literal: true

require "rails_helper"

describe ForwardMerge do
  describe "associations" do
    it "belongs to a release" do
      fmq = create(:forward_merge)
      expect(fmq.release).to be_present
    end

    it "has one commit" do
      release = create(:release)
      fmq = create(:forward_merge, release:)
      create(:commit, release:, forward_merge: fmq)
      expect(fmq.commit).to be_present
    end

    it "has one pull request" do
      release = create(:release)
      fmq = create(:forward_merge, release:)
      create(:pull_request, release:, forward_merge: fmq, kind: "cherry_pick")
      expect(fmq.pull_request).to be_present
    end
  end

  describe "#actionable?" do
    it "is actionable when pending" do
      fmq = build(:forward_merge, status: "pending")
      expect(fmq.actionable?).to be(true)
    end

    it "is actionable when failed" do
      fmq = build(:forward_merge, status: "failed")
      expect(fmq.actionable?).to be(true)
    end

    it "is not actionable when in_progress" do
      fmq = build(:forward_merge, status: "in_progress")
      expect(fmq.actionable?).to be(false)
    end

    it "is not actionable when success" do
      fmq = build(:forward_merge, status: "success")
      expect(fmq.actionable?).to be(false)
    end

    it "is not actionable when manually_picked" do
      fmq = build(:forward_merge, status: "manually_picked")
      expect(fmq.actionable?).to be(false)
    end
  end

  describe ".sequential" do
    it "orders by commit timestamp descending" do
      release = create(:release)
      fmq1 = create(:forward_merge, release:)
      fmq2 = create(:forward_merge, release:)
      create(:commit, release:, forward_merge: fmq1, timestamp: 1.hour.ago)
      create(:commit, release:, forward_merge: fmq2, timestamp: Time.current)

      result = described_class.sequential

      expect(result.first).to eq(fmq2)
      expect(result.last).to eq(fmq1)
    end
  end

  describe ".actionable" do
    it "returns only pending and failed records" do
      release = create(:release)
      pending_fmq = create(:forward_merge, release:, status: "pending")
      failed_fmq = create(:forward_merge, release:, status: "failed")
      create(:forward_merge, release:, status: "success")
      create(:forward_merge, release:, status: "in_progress")
      create(:forward_merge, release:, status: "manually_picked")

      result = described_class.actionable

      expect(result).to contain_exactly(pending_fmq, failed_fmq)
    end
  end

  describe "delegation" do
    it "delegates commit attributes" do
      release = create(:release)
      fmq = create(:forward_merge, release:)
      commit = create(:commit, release:, forward_merge: fmq)

      expect(fmq.short_sha).to eq(commit.short_sha)
      expect(fmq.commit_hash).to eq(commit.commit_hash)
      expect(fmq.message).to eq(commit.message)
      expect(fmq.author_name).to eq(commit.author_name)
    end
  end
end
