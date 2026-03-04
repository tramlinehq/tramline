# frozen_string_literal: true

require "rails_helper"

describe Webhooks::WorkingBranchPushJob do
  let(:train) { create(:train, :with_almost_trunk, backmerge_strategy: "cherry_pick") }
  let(:release) { create(:release, :on_track, train:) }

  let(:commit_data) do
    {
      commit_hash: SecureRandom.uuid.split("-").join,
      message: Faker::Lorem.sentence,
      timestamp: Time.current.iso8601,
      author_name: Faker::Name.name,
      author_email: Faker::Internet.email,
      author_login: Faker::Internet.user_name,
      url: Faker::Internet.url
    }
  end

  let(:rest_commits) do
    [
      {
        commit_hash: SecureRandom.uuid.split("-").join,
        message: Faker::Lorem.sentence,
        timestamp: Time.current.iso8601,
        author_name: Faker::Name.name,
        author_email: Faker::Internet.email,
        author_login: Faker::Internet.user_name,
        url: Faker::Internet.url
      }
    ]
  end

  it "creates a forward merge queue entry for the head commit" do
    expect {
      described_class.new.perform(release.id, commit_data.stringify_keys, [])
    }.to change(ForwardMerge, :count).by(1)
      .and change(Commit, :count).by(1)
  end

  it "creates forward merge queue entries for all commits" do
    expect {
      described_class.new.perform(release.id, commit_data.stringify_keys, rest_commits.map(&:stringify_keys))
    }.to change(ForwardMerge, :count).by(2)
      .and change(Commit, :count).by(2)
  end

  it "links the commit to its forward merge queue entry" do
    described_class.new.perform(release.id, commit_data.stringify_keys, [])

    fmq = ForwardMerge.last
    expect(fmq.commit).to be_present
    expect(fmq.commit.commit_hash).to eq(commit_data[:commit_hash])
    expect(fmq.status).to eq("pending")
  end

  it "does not create duplicate entries for the same commit" do
    described_class.new.perform(release.id, commit_data.stringify_keys, [])

    expect {
      described_class.new.perform(release.id, commit_data.stringify_keys, [])
    }.not_to change(ForwardMerge, :count)
  end

  it "does nothing if the release is not committable" do
    release.update!(status: "post_release")

    expect {
      described_class.new.perform(release.id, commit_data.stringify_keys, [])
    }.not_to change(ForwardMerge, :count)
  end

  it "associates the commit with the release" do
    described_class.new.perform(release.id, commit_data.stringify_keys, [])

    commit = Commit.last
    expect(commit.release).to eq(release)
    expect(commit.forward_merge).to be_present
  end
end
