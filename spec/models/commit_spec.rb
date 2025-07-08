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

    it "scopes to release correctly" do
      release1 = create(:release)
      release2 = create(:release)
      commit1 = create(:commit, release: release1, message: "commit1")
      commit2 = create(:commit, release: release1, message: "commit2")
      commit3 = create(:commit, release: release2, message: "commit2")
      commit4 = create(:commit, release: release2, message: "commit2")

      expect(release1.all_commits.commit_messages).to contain_exactly(commit1.message, commit2.message)
      expect(release2.all_commits.commit_messages).to contain_exactly(commit3.message, commit4.message)
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

    context "when excluding mid_release PRs" do
      it "excludes mid_release PR merge commits from the last 2 releases by default" do
        train = create(:train)

        # Create previous releases
        release1 = create(:release, :finished, train:, completed_at: 3.days.ago)
        release2 = create(:release, :finished, train:, completed_at: 2.days.ago)
        current_release = create(:release, train:)

        # Create commits for current release
        commit1 = create(:commit, release: current_release, message: "regular commit 1")
        commit2 = create(:commit, release: current_release, message: "regular commit 2")
        _merge_commit1 = create(:commit, release: current_release, message: "Merge PR #123", commit_hash: "merge_sha_1")
        _merge_commit2 = create(:commit, release: current_release, message: "Merge PR #456", commit_hash: "merge_sha_2")

        # Create mid_release PRs in previous releases that were merged
        create(:pull_request, release: release1, merge_commit_sha: "merge_sha_1")
        create(:pull_request, release: release2, merge_commit_sha: "merge_sha_2")

        # Should exclude the merge commits from mid_release PRs
        expect(current_release.all_commits.commit_messages).to contain_exactly(commit1.message, commit2.message)
      end

      it "includes mid_release PR merge commits when exclude_mid_release_prs is false" do
        train = create(:train)

        # Create previous releases
        release1 = create(:release, :finished, train:, completed_at: 3.days.ago)
        release2 = create(:release, :finished, train:, completed_at: 2.days.ago)
        current_release = create(:release, train:)

        # Create commits for current release
        commit1 = create(:commit, release: current_release, message: "regular commit 1")
        commit2 = create(:commit, release: current_release, message: "regular commit 2")
        merge_commit1 = create(:commit, release: current_release, message: "Merge PR #123", commit_hash: "merge_sha_1")
        merge_commit2 = create(:commit, release: current_release, message: "Merge PR #456", commit_hash: "merge_sha_2")

        # Create mid_release PRs in previous releases that were merged
        create(:pull_request, release: release1, merge_commit_sha: "merge_sha_1")
        create(:pull_request, release: release2, merge_commit_sha: "merge_sha_2")

        # Should include all commits when exclusion is disabled
        expect(current_release.all_commits.commit_messages(false, false)).to contain_exactly(
          commit1.message,
          commit2.message,
          merge_commit1.message,
          merge_commit2.message
        )
      end

      it "handles cases where there are no previous releases" do
        train = create(:train)
        current_release = create(:release, train:)

        # Create commits for current release
        commit1 = create(:commit, release: current_release, message: "regular commit 1")
        commit2 = create(:commit, release: current_release, message: "regular commit 2")

        # Should return all commits when there are no previous releases
        expect(current_release.all_commits.commit_messages).to contain_exactly(commit1.message, commit2.message)
      end

      it "only excludes mid_release PRs, not other types of PRs" do
        train = create(:train)

        # Create previous releases
        release1 = create(:release, :finished, train:, completed_at: 3.days.ago)
        current_release = create(:release, train:)

        # Create commits for current release
        commit1 = create(:commit, release: current_release, message: "regular commit 1")
        _merge_commit1 = create(:commit, release: current_release, message: "Merge PR #123", commit_hash: "merge_sha_1")
        merge_commit2 = create(:commit, release: current_release, message: "Merge PR #456", commit_hash: "merge_sha_2")

        # Create different types of PRs in previous release
        create(:pull_request, release: release1, phase: "mid_release", merge_commit_sha: "merge_sha_1")
        create(:pull_request, release: release1, phase: "pre_release", merge_commit_sha: "merge_sha_2")

        # Should only exclude the mid_release PR merge commit
        expect(current_release.all_commits.commit_messages).to contain_exactly(
          commit1.message,
          merge_commit2.message
        )
      end

      it "only considers PRs with merge_commit_sha populated" do
        train = create(:train)

        # Create previous releases
        release1 = create(:release, :finished, train:, completed_at: 3.days.ago)
        current_release = create(:release, train:)

        # Create commits for current release
        commit1 = create(:commit, release: current_release, message: "regular commit 1")
        merge_commit1 = create(:commit, release: current_release, message: "Merge PR #123", commit_hash: "merge_sha_1")

        # Create mid_release PR without merge_commit_sha (not yet merged)
        create(:pull_request, release: release1, merge_commit_sha: nil)

        # Should include all commits since the PR doesn't have a merge commit SHA
        expect(current_release.all_commits.commit_messages).to contain_exactly(
          commit1.message,
          merge_commit1.message
        )
      end

      it "respects first_parent_only flag while excluding mid_release PRs" do
        train = create(:train)

        # Create previous release
        release1 = create(:release, :finished, train:, completed_at: 3.days.ago)
        current_release = create(:release, train:)

        # Create commits with parent relationships
        commit1 = create(:commit, release: current_release, message: "commit1", parents: [{sha: "parent_sha"}])
        commit2 = create(:commit, release: current_release, message: "commit2", parents: [{sha: "parent_sha"}])
        commit3 = create(:commit, release: current_release, message: "commit3", parents: [{sha: commit1.commit_hash}])
        _merge_commit = create(:commit, release: current_release, message: "Merge PR #123",
          commit_hash: "merge_sha_1",
          parents: [{sha: commit2.commit_hash}, {sha: commit3.commit_hash}])

        # Create mid_release PR in previous release
        create(:pull_request, release: release1, merge_commit_sha: "merge_sha_1")

        # With first_parent_only, should exclude branch commits AND mid_release PR merge
        expect(current_release.all_commits.commit_messages(true)).to contain_exactly(commit2.message)
      end
    end
  end
end
