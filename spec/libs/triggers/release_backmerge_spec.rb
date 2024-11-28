# frozen_string_literal: true

require "rails_helper"

describe Triggers::ReleaseBackmerge do
  let(:train) { create(:train, :with_almost_trunk, backmerge_strategy: "continuous") }
  let(:release) { create(:release, :on_track, train:) }
  let(:commit) { create(:commit, release:) }

  before do
    allow(Triggers::PatchPullRequest).to receive(:create!).and_return(GitHub::Result.new { true })
  end

  it "does nothing if the train is not configured for backmerge" do
    train.update!(backmerge_strategy: "on_finalize")

    described_class.call(commit)

    expect(Triggers::PatchPullRequest).not_to have_received(:create!)
  end

  it "creates a patch PR for the commit" do
    described_class.call(commit)

    expect(Triggers::PatchPullRequest).to have_received(:create!)
  end

  context "when patch or backmerge PR fails" do
    before do
      allow(Triggers::PatchPullRequest).to receive(:create!).and_return(GitHub::Result.new { raise "Failed to create patch pull request" })
    end

    it "marks the commit as backmerge failed" do
      described_class.call(commit)
      expect(commit.reload.backmerge_failure).to be(true)
    end

    it "notifies about the backmerge failure" do
      allow(commit).to receive(:notify!)
      described_class.call(commit)
      expect(commit).to have_received(:notify!).with("Backmerge to the working branch failed", :backmerge_failed, commit.notification_params)
    end
  end
end
