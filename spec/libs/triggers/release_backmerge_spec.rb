# frozen_string_literal: true

require "rails_helper"

describe Triggers::ReleaseBackmerge do
  let(:train) { create(:train, :with_almost_trunk, backmerge_strategy: "continuous") }
  let(:release) { create(:release, :on_track, train:) }
  let!(:first_commit) { create(:commit, release:) }

  before do
    allow(Triggers::PatchPullRequest).to receive(:create!).and_return(GitHub::Result.new { true })
  end

  it "does nothing if the train is not configured for backmerge" do
    train.update!(backmerge_strategy: "on_finalize")
    commit = create(:commit, release:)

    described_class.call(commit)

    expect(Triggers::PatchPullRequest).not_to have_received(:create!)
  end

  it "does nothing if cherry-picks are not allowed and it is not a head commit" do
    app = create(:app, platform: :android)
    vcs_providable = create(:bitbucket_integration, :without_callbacks_and_validations)
    _vcs_provider = create(:integration, category: "version_control", providable: vcs_providable, integrable: app)
    train = create(:train, :with_almost_trunk, app:, backmerge_strategy: "continuous")
    release = create(:release, :on_track, train:)
    commit = create(:commit, release:)

    described_class.call(commit, is_head_commit: false)

    expect(Triggers::PatchPullRequest).not_to have_received(:create!)
  end

  it "does not create a patch PR it there is only one commit" do
    described_class.call(first_commit)
    expect(Triggers::PatchPullRequest).not_to have_received(:create!)
  end

  it "creates a patch PR for the commit" do
    commit = create(:commit, release:)
    described_class.call(commit)

    expect(Triggers::PatchPullRequest).to have_received(:create!)
  end

  context "when patch or backmerge PR fails" do
    before do
      fail_result = GitHub::Result.new { raise "Failed to create patch pull request" }
      allow(Triggers::PatchPullRequest).to receive(:create!).and_return(fail_result)
    end

    it "marks the commit as backmerge failed" do
      commit = create(:commit, release:)
      described_class.call(commit)

      expect(commit.reload.backmerge_failure).to be(true)
    end

    it "notifies about the backmerge failure" do
      commit = create(:commit, release:)
      allow(commit).to receive(:notify!)
      described_class.call(commit)

      expect(commit).to have_received(:notify!).with("Backmerge to the working branch failed", :backmerge_failed, commit.notification_params)
    end
  end
end
