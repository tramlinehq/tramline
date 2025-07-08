# == Schema Information
#
# Table name: commits
#
#  id                      :uuid             not null, primary key
#  author_email            :string           not null
#  author_login            :string
#  author_name             :string           not null
#  backmerge_failure       :boolean          default(FALSE)
#  commit_hash             :string           not null, indexed => [release_id, release_changelog_id]
#  message                 :string           indexed
#  parents                 :jsonb
#  search_vector           :tsvector         indexed
#  timestamp               :datetime         not null, indexed => [release_id]
#  url                     :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  build_queue_id          :uuid             indexed
#  release_changelog_id    :uuid             indexed => [commit_hash, release_id], indexed
#  release_id              :uuid             indexed => [commit_hash, release_changelog_id], indexed => [timestamp]
#  release_platform_id     :uuid             indexed
#  release_platform_run_id :uuid             indexed
#
class Commit < ApplicationRecord
  has_paper_trail
  include Passportable
  include Commitable
  include Searchable

  self.implicit_order_column = :timestamp

  has_many :release_platform_runs, dependent: :nullify, inverse_of: :last_commit
  belongs_to :release, inverse_of: :all_commits
  belongs_to :release_changelog, inverse_of: :commits, optional: true
  belongs_to :build_queue, inverse_of: :commits, optional: true
  belongs_to :user, foreign_key: "author_login", primary_key: "github_login", optional: true, inverse_of: :commits, class_name: "Accounts::User"
  has_one :pull_request, inverse_of: :commit, dependent: :nullify

  scope :sequential, -> { order(timestamp: :desc) }
  scope :stability, -> { where(release_changelog: nil) }
  scope :changelog, -> { where.not(stability.where_values_hash) }

  STAMPABLE_REASONS = ["created"]

  validates :commit_hash, uniqueness: {scope: [:release_id, :release_changelog_id]}

  before_save :generate_search_vector_data
  after_commit -> { create_stamp!(data: {sha: short_sha}) }, on: :create, if: :stability?

  delegate :release_platform_runs, :notify!, :train, :platform, to: :release

  pg_search_scope :search_by_message,
    against: :message,
    **search_config

  def self.commit_messages(first_parent_only = false, exclude_mid_release_prs = true)
    commits = commit_log(reorder("timestamp DESC"), first_parent_only)
    release = commits.first&.release

    recent_pr_merge_commit_shas = []
    if exclude_mid_release_prs && commits.any? && release
      last_few_releases = release.previous_releases(2).pluck(:id)
      recent_pr_merge_commit_shas =
        PullRequest.mid_release
          .where(release: last_few_releases)
          .where.not(merge_commit_sha: nil)
          .pluck(:merge_commit_sha)
    end

    if recent_pr_merge_commit_shas.any?
      commits = commits.reject { |commit| recent_pr_merge_commit_shas.include?(commit.commit_hash) }
    end

    commits.map(&:message)
  end

  def self.count_by_team(org)
    return unless org.teams.exists?

    res = reorder("")
      .left_outer_joins(user: [memberships: :team])
      .where("memberships.organization_id = ? OR memberships.organization_id IS NULL", org.id)
      .group("COALESCE(teams.name, '#{Accounts::Team::UNKNOWN_TEAM_NAME}')")
      .count("commits.id")
      .sort_by(&:last)
      .reverse
      .to_h

    org.team_names.each { |team_name| res[team_name] ||= 0 }
    res
  end

  def self.between_commits(base_commit, head_commit)
    return none if head_commit.nil?
    return none if base_commit.nil? && head_commit.nil?

    base_condition = where(release_id: (base_commit || head_commit).release.id).reorder(timestamp: :desc)

    if base_commit
      base_condition
        .where("timestamp > ? AND timestamp <= ?", base_commit.timestamp, head_commit.timestamp)
    else
      base_condition
        .where(timestamp: ..head_commit.timestamp)
    end
  end

  def team
    user&.team_for(release.organization)
  end

  def applicable?
    commit_hash == release.latest_commit_hash
  rescue
    true
  end

  def author_url
    url
  end

  def stale?
    release.applied_commits.last != self
  end

  def short_sha
    commit_hash[0, 7]
  end

  def notification_params
    release.notification_params.merge(
      {
        commit_sha: short_sha,
        commit_url: url,
        commit_author: author_name,
        commit_author_email: author_email,
        # NOTE: Truncate the message to 200 characters to avoid Slack notifications from exceeding the 2000 character limit
        # and also to not pollute the notifications channel with too much information
        commit_message: message&.truncate(200),
        commit_timestamp: timestamp
      }
    )
  end

  def changelog?
    release_changelog_id.present?
  end

  def stability?
    !changelog?
  end

  private

  def generate_search_vector_data
    self.search_vector = self.class.generate_search_vector(message)
  end
end
