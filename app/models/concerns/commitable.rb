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

  class NormalizedCommit
    def initialize(commit, train: nil)
      @commit = commit
      @train = train
    end

    attr_reader :train

    def author_name = commit["author_name"]

    def author_login = commit["author_login"]

    def author_email = commit["author_email"]

    def url = commit["url"]

    def author_url = commit["author_url"]

    def timestamp
      time = commit["author_timestamp"] || commit["timestamp"]
      Time.zone.parse(time) if time
    end

    def commit_hash = commit["sha"] || commit["commit_hash"]

    def short_sha = commit_hash[0, 7]

    def truncated_message = commit["message"]&.truncate(70)

    def applied_at = nil

    def parents = commit["parents"]

    def message = commit["message"]

    def team = nil # TODO: stub

    def pull_request = nil

    def backmerge_failure? = nil

    def eql?(other)
      commit_hash == other.commit_hash
    end

    alias_method :==, :eql?

    private

    attr_reader :commit
  end
end
