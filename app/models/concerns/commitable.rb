module Commitable
  extend ActiveSupport::Concern

  class_methods do
    def messages_for(commits, first_parent_only = false)
      return commits.map(&:message) unless first_parent_only

      parent_commits = []
      next_parent_sha = nil

      commits.each do |commit|
        next if next_parent_sha.present? && next_parent_sha != commit.commit_hash
        parent_commits << commit
        next_parent_sha = (commit.parents.present? && commit.parents.size > 1) ? commit.parents[0][:sha] : nil
      end
      parent_commits.map(&:message)
    end
  end
end
