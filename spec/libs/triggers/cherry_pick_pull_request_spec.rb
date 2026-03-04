# frozen_string_literal: true

require "rails_helper"

describe Triggers::CherryPickPullRequest do
  let(:train) { create(:train, :with_almost_trunk, backmerge_strategy: "cherry_pick") }
  let(:release) { create(:release, train:) }
  let(:fmq) { create(:forward_merge_queue, release:) }
  let(:commit) { create(:commit, release:, forward_merge_queue: fmq) }
  let(:repo_integration) { instance_double(GithubIntegration) }
  let(:expected_patch_branch) { "cherry-pick-#{release.branch_name.parameterize}-#{commit.short_sha}" }
  let(:expected_title) { "[CHERRY-PICK] [#{release.release_version}] #{commit.message.to_s.split("\n").first}".gsub(/\s*\(#\d+\)/, "").squish }
  let(:pr_source_id) { Faker::Lorem.word }
  let(:pr_number) { Faker::Number.number(digits: 2) }
  let(:created_pr) do
    {
      source_id: pr_source_id,
      number: pr_number,
      title: expected_title,
      body: Faker::Lorem.paragraph,
      url: Faker::Internet.url,
      state: "open",
      head_ref: expected_patch_branch,
      base_ref: release.branch_name,
      opened_at: Time.current,
      source: :github
    }
  end
  let(:merged_pr) do
    created_pr.merge(state: "closed")
  end

  before do
    # Ensure the commit is created
    commit
    allow(train).to receive(:vcs_provider).and_return(repo_integration)
    allow(repo_integration).to receive_messages(
      create_patch_pr!: created_pr,
      get_pr: created_pr,
      pr_closed?: false,
      enable_auto_merge!: true,
      enable_auto_merge?: true,
      merge_pr!: merged_pr
    )
  end

  it "creates a patch PR targeting the release branch" do
    described_class.call(release, fmq)

    expect(repo_integration).to have_received(:create_patch_pr!).with(
      release.branch_name,
      expected_patch_branch,
      commit.commit_hash,
      expected_title,
      anything
    )
  end

  it "creates a cherry_pick kind pull request" do
    described_class.call(release, fmq)

    pr = release.pull_requests.cherry_pick_type.last
    expect(pr).to be_present
    expect(pr.phase).to eq("mid_release")
    expect(pr.kind).to eq("cherry_pick")
  end

  it "includes commit info in the PR description" do
    described_class.call(release, fmq)

    expect(repo_integration).to have_received(:create_patch_pr!).with(
      anything,
      anything,
      anything,
      anything,
      include(commit.commit_hash)
    )
  end

  it "links the pull request to the forward merge queue" do
    described_class.call(release, fmq)

    pr = release.pull_requests.cherry_pick_type.last
    expect(pr.forward_merge_queue_id).to eq(fmq.id)
  end
end
