module Commitable
  extend ActiveSupport::Concern

  class_methods do
    def commit_log(commits, first_parent_only = false)
      return if commits.empty?
      return commits unless first_parent_only
      return commits if commits.any? { |c| c.parents.blank? }

      commit_map = commits.index_by(&:commit_hash)
      first_commit = commits.first
      parent_commits = [first_commit]
      next_parent_sha = first_commit.parents[0]["sha"]

      while next_parent_sha
        commit = commit_map[next_parent_sha]
        next_parent_sha = commit&.parents&.dig(0, "sha")
        parent_commits << commit if commit
      end

      parent_commits
    end
  end
end
