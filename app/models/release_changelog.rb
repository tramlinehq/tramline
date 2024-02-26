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

  def commits_by_team
    return unless release.organization.teams.exists?

    relevant_commits = normalized_commits
    user_logins = relevant_commits.map(&:author_login).uniq
    users = Accounts::User
      .joins(memberships: [:team, :organization])
      .where(github_login: user_logins, memberships: {organization: release.organization})
      .select("github_login", "teams.name AS team_name")

    by_team = relevant_commits.group_by(&:author_login).each_with_object({}) do |(login, commits), teams_data|
      user = users.find { |user| user.github_login == login }
      team_name = user&.team_name || Accounts::Team::UNKNOWN_TEAM_NAME

      teams_data[team_name] = 0 unless teams_data.key?(team_name)
      teams_data[team_name] += commits.size
    end

    by_team.sort_by(&:last).reverse.to_h
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

    def timestamp = commit["author_timestamp"] || commit["timestamp"]

    def commit_hash = commit["sha"] || commit["commit_hash"]

    def short_sha = commit_hash[0, 7]

    def truncated_message = commit["message"]&.truncate(70)

    def applied_at = nil

    private

    attr_reader :commit
  end
end
