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
  include Commitable

  belongs_to :release

  def normalized_commits
    commits.map { NormalizedCommit.new(_1, train: release.train) }.sort_by(&:timestamp).reverse
  end

  def commit_messages(first_parent_only = false)
    ReleaseChangelog.commit_log(normalized_commits.sort_by(&:timestamp).reverse, first_parent_only)&.map(&:message)
  end

  def unique_authors
    commits.pluck("author_name").uniq
  end

  def commits_by_team
    return unless release.organization.teams.exists?

    relevant_commits = normalized_commits.reject { |c| c.author_login.nil? }
    user_logins = relevant_commits.map(&:author_login).uniq
    users = Accounts::User
      .joins(memberships: [:team, :organization])
      .where(github_login: user_logins, memberships: {organization: release.organization})
      .select("github_login", "teams.name AS team_name")

    by_team = relevant_commits.group_by(&:author_login).each_with_object({}) do |(login, commits), teams_data|
      if login == release.vcs_provider.bot_name
        team_name = Accounts::Team::TRAMLINE_TEAM_NAME
      else
        user = users.find { |user| user.github_login == login }
        team_name = user&.team_name || Accounts::Team::UNKNOWN_TEAM_NAME
      end

      teams_data[team_name] = 0 unless teams_data.key?(team_name)
      teams_data[team_name] += commits.size
    end

    release.organization.team_names.each { |team_name| by_team[team_name] ||= 0 }
    by_team[Accounts::Team::TRAMLINE_TEAM_NAME] ||= 0
    by_team.sort_by(&:last).reverse.to_h
  end
end
