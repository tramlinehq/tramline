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

    it "filters out commits matching tramline-created pull requests" do
      train = create(:train)
      current_release = create(:release, train: train)
      previous_release = create(:release, :finished, train: train)

      # Create commits for current release
      commit1 = create(:commit, release: current_release, message: "regular commit", commit_hash: "abc123")
      commit2 = create(:commit, release: current_release, message: "pr merge commit", commit_hash: "def456")
      commit3 = create(:commit, release: current_release, message: "another regular commit", commit_hash: "ghi789")

      # Create a pull request in previous release with merge_commit_sha matching commit2
      create(:pull_request, release: previous_release, merge_commit_sha: "def456")

      # Test filtering with previous releases
      result = current_release.all_commits.commit_messages(Release.where(id: previous_release.id))

      expect(result).to contain_exactly(commit1.message, commit3.message)
      expect(result).not_to include(commit2.message)
    end

    it "returns all commits when no previous releases provided" do
      release = create(:release)
      commit1 = create(:commit, release: release, message: "commit1")
      commit2 = create(:commit, release: release, message: "commit2")

      result = release.all_commits.commit_messages(Release.none)

      expect(result).to contain_exactly(commit1.message, commit2.message)
    end
    
    it "returns all commits when previous releases have no pull requests" do
      train = create(:train)
      current_release = create(:release, train: train)
      previous_release = create(:release, :finished, train: train)

      commit1 = create(:commit, release: current_release, message: "commit1")
      commit2 = create(:commit, release: current_release, message: "commit2")

      result = current_release.all_commits.commit_messages(Release.where(id: previous_release.id))

      expect(result).to contain_exactly(commit1.message, commit2.message)
    end
    
    it "returns all commits when pull requests have nil merge_commit_sha" do
      train = create(:train)
      current_release = create(:release, train: train)
      previous_release = create(:release, :finished, train: train)

      commit1 = create(:commit, release: current_release, message: "commit1")
      commit2 = create(:commit, release: current_release, message: "commit2")

      # Create PR with nil merge_commit_sha
      create(:pull_request, release: previous_release, merge_commit_sha: nil)

      result = current_release.all_commits.commit_messages(Release.where(id: previous_release.id))

      expect(result).to contain_exactly(commit1.message, commit2.message)
    end
    
    it "filters commits from multiple previous releases" do
      train = create(:train)
      current_release = create(:release, train: train)
      previous_release1 = create(:release, :finished, train: train)
      previous_release2 = create(:release, :finished, train: train)

      commit1 = create(:commit, release: current_release, message: "regular commit", commit_hash: "abc123")
      commit2 = create(:commit, release: current_release, message: "pr merge 1", commit_hash: "def456")
      commit3 = create(:commit, release: current_release, message: "pr merge 2", commit_hash: "ghi789")
      commit4 = create(:commit, release: current_release, message: "another regular", commit_hash: "jkl012")

      create(:pull_request, release: previous_release1, merge_commit_sha: "def456")
      create(:pull_request, release: previous_release2, merge_commit_sha: "ghi789")

      result = current_release.all_commits.commit_messages(Release.where(id: [previous_release1.id, previous_release2.id]))

      expect(result).to contain_exactly(commit1.message, commit4.message)
      expect(result).not_to include(commit2.message, commit3.message)
    end
    
    it "works with first_parent_only parameter" do
      train = create(:train)
      current_release = create(:release, train: train)
      previous_release = create(:release, :finished, train: train)

      commit1 = create(:commit, release: current_release, message: "regular commit", commit_hash: "abc123", parents: [{sha: "parent1"}])
      commit2 = create(:commit, release: current_release, message: "pr merge commit", commit_hash: "def456", parents: [{sha: "parent2"}])

      create(:pull_request, release: previous_release, merge_commit_sha: "def456")

      result = current_release.all_commits.commit_messages(Release.where(id: previous_release.id), true)

      expect(result).to contain_exactly(commit1.message)
      expect(result).not_to include(commit2.message)
    end
  end
end
