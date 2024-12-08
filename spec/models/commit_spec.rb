require "rails_helper"

describe Commit do
  it "has valid factory" do
    expect(create(:commit)).to be_valid
  end

  describe ".commit_messages" do
    it "returns commit messages" do
      release = create(:release)
      commit1 = create(:commit, release:, message: "commit1")
      commit2 = create(:commit, release:, message: "commit2")

      expect(release.all_commits.commit_messages).to contain_exactly(commit1.message, commit2.message)
    end

    it "returns first parent commit messages when no parent defined" do
      release = create(:release)
      commit1 = create(:commit, release:, message: "commit1")
      commit2 = create(:commit, release:, message: "commit2")

      expect(release.all_commits.commit_messages(true)).to contain_exactly(commit1.message, commit2.message)
    end

    it "returns first parent commit messages when parents defined" do
      release = create(:release)
      commit1 = create(:commit, release:, message: "commit1", parents: [{sha: "parent_sha"}])
      commit2 = create(:commit, release:, message: "commit2", parents: [{sha: commit1.commit_hash}])

      expect(release.all_commits.commit_messages(true)).to contain_exactly(commit1.message, commit2.message)
    end

    it "skips messages which are not first parent" do
      release = create(:release)
      commit1 = create(:commit, release:, message: "commit1", parents: [{sha: "parent_sha"}]) # new feature branch of main
      commit2 = create(:commit, release:, message: "commit2", parents: [{sha: "parent_sha"}]) # new commit on main
      commit3 = create(:commit, release:, message: "commit3", parents: [{sha: commit1.commit_hash}]) # feature branch commit
      commit4 = create(:commit, release:, message: "commit4", parents: [{sha: commit2.commit_hash}, {sha: commit3.commit_hash}]) # merge of feature branch to main

      expect(release.all_commits.commit_messages(true)).to contain_exactly(commit2.message, commit4.message)
    end

    it "does not skip messages when first parent is not true" do
      release = create(:release)
      commit1 = create(:commit, release:, message: "commit1", parents: [{sha: "parent_sha"}]) # new feature branch of main
      commit2 = create(:commit, release:, message: "commit2", parents: [{sha: "parent_sha"}]) # new commit on main
      commit3 = create(:commit, release:, message: "commit3", parents: [{sha: commit1.commit_hash}]) # feature branch commit
      commit4 = create(:commit, release:, message: "commit4", parents: [{sha: commit2.commit_hash}, {sha: commit3.commit_hash}]) # merge of feature branch to main

      expect(release.all_commits.commit_messages).to contain_exactly(commit1.message, commit2.message, commit3.message, commit4.message)
    end
  end
end
