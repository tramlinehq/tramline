# frozen_string_literal: true

require "rails_helper"

describe Triggers::PatchPullRequest do
  let(:train) { create(:train) }
  let(:release) { create(:release, train:) }
  let(:commit) { create(:commit, release:) }
  let(:repo_integration) { instance_double(GithubIntegration) }
  let(:expected_title) { "[PATCH] [#{release.release_version}] #{commit.message}" }
  let(:expected_patch_branch) { "patch-#{train.working_branch}-#{commit.short_sha}" }
  let(:expected_description) {
    <<~TEXT
      - Cherry-pick #{commit.commit_hash} commit
      - Authored by: @#{commit.author_login}

      #{commit.message}
    TEXT
  }
  let(:created_pr) {
    {
      source_id: Faker::Lorem.word,
      number: Faker::Number.number(digits: 2),
      title: expected_title,
      body: expected_description,
      url: Faker::Internet.url,
      state: "open",
      head_ref: expected_patch_branch,
      base_ref: train.working_branch,
      opened_at: Time.current,
      source: :github
    }
  }

  before do
    allow(train).to receive(:vcs_provider).and_return(repo_integration)
    allow(repo_integration).to receive_messages(create_patch_pr!: created_pr, enable_auto_merge!: true)
  end

  it "creates a patch PR" do
    described_class.create!(release, commit)

    expect(repo_integration).to have_received(:create_patch_pr!).with(
      train.working_branch,
      expected_patch_branch,
      commit.commit_hash,
      expected_title,
      expected_description
    )
  end

  it "finds the PR if it already exists" do
    allow(repo_integration).to receive(:create_patch_pr!).and_raise(Installations::Error.new("duplicate", reason: :pull_request_already_exists))
    allow(repo_integration).to receive(:find_pr).and_return(created_pr)

    described_class.create!(release, commit)
    expect(repo_integration).to have_received(:find_pr)
  end

  it "creates an ongoing PR for the release" do
    described_class.create!(release, commit)

    expect(release.pull_requests.ongoing.size).to eq(1)
    persisted_pr = release.pull_requests.ongoing.sole
    expect(persisted_pr.title).to eq(expected_title)
    expect(persisted_pr.body).to eq(expected_description)
    expect(persisted_pr.head_ref).to eq(expected_patch_branch)
  end

  it "enables auto merge for the created patch PR" do
    described_class.create!(release, commit)

    expect(repo_integration).to have_received(:enable_auto_merge!)
  end
end
