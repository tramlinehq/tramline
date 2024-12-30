# == Schema Information
#
# Table name: commits
#
#  id                      :uuid             not null, primary key
#  author_email            :string           not null
#  author_login            :string
#  author_name             :string           not null
#  backmerge_failure       :boolean          default(FALSE)
#  commit_hash             :string           not null, indexed => [release_id]
#  message                 :string
#  parents                 :jsonb
#  timestamp               :datetime         not null, indexed => [release_id]
#  url                     :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  build_queue_id          :uuid             indexed
#  release_id              :uuid             indexed => [commit_hash], indexed => [timestamp]
#  release_platform_id     :uuid             indexed
#  release_platform_run_id :uuid             indexed
#
class Commit < ApplicationRecord
  has_paper_trail
  include Passportable
  include Commitable

  self.implicit_order_column = :timestamp

  has_many :release_platform_runs, dependent: :nullify, inverse_of: :last_commit
  belongs_to :release, inverse_of: :all_commits
  belongs_to :build_queue, inverse_of: :commits, optional: true
  belongs_to :user, foreign_key: "author_login", primary_key: "github_login", optional: true, inverse_of: :commits, class_name: "Accounts::User"
  has_one :pull_request, inverse_of: :commit, dependent: :nullify

  scope :sequential, -> { order(timestamp: :desc) }

  STAMPABLE_REASONS = ["created"]

  validates :commit_hash, uniqueness: {scope: :release_id}

  after_commit -> { create_stamp!(data: {sha: short_sha}) }, on: :create

  delegate :release_platform_runs, :notify!, :train, :platform, to: :release

  def self.commit_messages(first_parent_only = false)
    Commit.commit_log(reorder("timestamp DESC"), first_parent_only)&.map(&:message)
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
        commit_message: message.truncate(200),
        commit_timestamp: timestamp
      }
    )
  end
end
