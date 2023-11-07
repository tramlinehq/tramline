# == Schema Information
#
# Table name: release_changelogs
#
#  id         :uuid             not null, primary key
#  commits    :jsonb
#  from_ref   :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  release_id :uuid             not null, indexed
#
class ReleaseChangelog < ApplicationRecord
  has_paper_trail

  belongs_to :release

  def normalized_commits
    commits.map { NormalizedCommit.new(_1) }.sort_by(&:timestamp).reverse
  end

  def commit_messages
    commits.pluck("message")
  end

  def merge_commit_messages
    commits
      .filter { |c| c["parents"].size > 1 }
      .pluck("message")
  end

  def unique_authors
    commits.pluck("author_name").uniq
  end

  private

  class NormalizedCommit
    def initialize(commit)
      @commit = commit
    end

    def author_name = commit["author_name"]

    def author_login = commit["author_login"]

    def author_email = commit["author_email"]

    def url = commit["url"]

    def author_url = commit["author_url"]

    def timestamp = commit["author_timestamp"]

    def commit_hash = commit["sha"]

    def short_sha = commit_hash[0, 7]

    def truncated_message = commit["message"]&.truncate(70)

    private

    attr_reader :commit
  end
end
