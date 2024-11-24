# frozen_string_literal: true

require "rails_helper"

describe Triggers::ReleaseBackmerge do
  let(:the_app) { create(:app, platform: "android") }
  let(:cherry_pick_vcs) { create(:github_integration) }
  let(:train) { create(:train, :with_almost_trunk, app: the_app, backmerge_strategy: "continuous") }
  let(:release) { create(:release, :on_track, train:) }
  let(:commit) { create(:commit, release:) }

  it "does nothing if the train is not configured for backmerge" do
    allow(Triggers::PullRequest).to receive(:create_and_merge!).and_return(GitHub::Result.new { true })
    allow(Triggers::PatchPullRequest).to receive(:create!).and_return(GitHub::Result.new { true })
    train.update!(backmerge_strategy: "on_finalize")

    described_class.call(commit)

    expect(Triggers::PullRequest).not_to have_received(:create_and_merge!)
    expect(Triggers::PatchPullRequest).not_to have_received(:create!)
  end

  context "when cherry-picking is allowed" do
    before do
      create(:integration, category: "version_control", providable: cherry_pick_vcs, integrable: the_app)
    end

    it "creates a patch PR for the commit" do
      allow(Triggers::PatchPullRequest).to receive(:create!).and_return(GitHub::Result.new { true })

      described_class.call(commit)

      expect(Triggers::PatchPullRequest).to have_received(:create!)
    end
  end

  context "when cherry-picking is not allowed" do
    let(:without_cherry_pick_vcs) { instance_double(BitbucketIntegration) }
    let(:expected_pr_title) { "[#{release.release_version}] Continuous merge back from release" }
    let(:expected_pr_description) { "Release #{release.release_version} (#{train.name}) has new changes on this release branch.\nMerge these changes back into `#{train.working_branch}` to keep it in sync.\n" }
    let(:create_payload) {
      {
        source_id: Faker::Number.number(digits: 4),
        number: 1,
        state: "OPEN",
        title: expected_pr_title,
        body: expected_pr_description,
        head_ref: Faker::Lorem.word,
        base_ref: Faker::Lorem.word,
        opened_at: Time.current,
        source: "bitbucket"
      }
    }
    let(:merge_payload) { create_payload.merge(state: "MERGED") }

    before do
      allow_any_instance_of(Train).to receive(:vcs_provider).and_return(without_cherry_pick_vcs)
      allow(without_cherry_pick_vcs).to receive_messages(create_pr!: create_payload,
        merge_pr!: merge_payload,
        get_pr: create_payload,
        supports_cherry_pick?: false)
    end

    it "creates and merges an ongoing PR between release branch and working branch" do
      described_class.call(commit)

      expect(without_cherry_pick_vcs).to have_received(:create_pr!).with(train.working_branch, release.release_branch, expected_pr_title, expected_pr_description)
      expect(without_cherry_pick_vcs).to have_received(:merge_pr!)
      created_pr = release.reload.pull_requests.ongoing.closed.sole.slice(:title, :body, :state)
      expect(created_pr).to match(title: expected_pr_title, body: expected_pr_description, state: "closed")
    end

    it "does not create a PR if an open one already exists" do
      allow(without_cherry_pick_vcs).to receive(:pr_closed?).and_return(false)
      existing_pr = create(:pull_request, release:, state: "open", phase: "ongoing")

      described_class.call(commit)

      expect(without_cherry_pick_vcs).not_to have_received(:create_pr!)
      expect(without_cherry_pick_vcs).to have_received(:merge_pr!)
      expect(existing_pr.reload.closed?).to be(true)
    end
  end

  context "when patch or backmerge PR fails" do
    before do
      create(:integration, category: "version_control", providable: cherry_pick_vcs, integrable: the_app)
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
