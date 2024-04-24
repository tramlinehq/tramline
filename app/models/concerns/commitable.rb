module Commitable
  extend ActiveSupport::Concern

  class_methods do
    def messages_for(commits, first_parent_only = false)
      return commits.map(&:message) unless first_parent_only
      return commits.map(&:message) if commits.any? { |c| c.parents.blank? }

      commit_map = commits.index_by(&:commit_hash)
      first_commit = commits.first
      parent_commits = [first_commit]
      next_parent_sha = first_commit.parents[0]["sha"]

      while next_parent_sha
        commit = commit_map[next_parent_sha]
        next_parent_sha = commit&.parents&.dig(0, "sha")
        parent_commits << commit if commit
      end

      parent_commits.map(&:message)
    end
  end
end
