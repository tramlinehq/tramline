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
#  timestamp               :datetime         not null
#  url                     :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  build_queue_id          :uuid             indexed
#  release_id              :uuid             indexed => [commit_hash]
#  release_platform_id     :uuid             indexed
#  release_platform_run_id :uuid             indexed
#
class Commit < ApplicationRecord
  include Passportable
  include Commitable

  self.implicit_order_column = :timestamp

  has_many :step_runs, dependent: :nullify, inverse_of: :commit
  has_many :release_platform_runs, dependent: :nullify, inverse_of: :last_commit
  belongs_to :release, inverse_of: :all_commits
  belongs_to :build_queue, inverse_of: :commits, optional: true
  belongs_to :user, foreign_key: "author_login", primary_key: "github_login", optional: true, inverse_of: :commits, class_name: "Accounts::User"
  has_one :pull_request, inverse_of: :commit, dependent: :nullify

  scope :sequential, -> { order(timestamp: :desc) }

  STAMPABLE_REASONS = ["created"]

  validates :commit_hash, uniqueness: {scope: :release_id}

  after_commit -> { create_stamp!(data: {sha: short_sha}) }, on: :create
  after_create_commit -> { Releases::BackmergeCommitJob.perform_later(id) }, if: -> { release.release_changes? }

  delegate :release_platform_runs, :notify!, :train, :platform, to: :release

  def self.commit_messages(first_parent_only = false)
    Commit.messages_for(all.reorder("timestamp DESC"), first_parent_only).map(&:message)
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

  def self.between(base_step_run, head_step_run)
    return none if head_step_run.nil?
    return none if base_step_run.nil? && head_step_run.nil?

    base_condition = where(release_id: (base_step_run || head_step_run).release.id)
      .order(created_at: :desc)

    if base_step_run
      base_condition
        .where("created_at > ? AND created_at <= ?", base_step_run.commit.created_at, head_step_run.commit.created_at)
    else
      base_condition
        .where("created_at <= ?", head_step_run.commit.created_at)
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

  def run_for(step, release_platform_run)
    step_runs.where(step:, release_platform_run:).last
  end

  def stale?
    release.applied_commits.last != self
  end

  def short_sha
    commit_hash[0, 7]
  end

  def step_runs_for(platform_run)
    step_runs.where(release_platform_run: platform_run).includes(:step)
  end

  def applied_at
    step_runs.map(&:created_at).min
  end

  def trigger_step_runs_for(platform_run, force: false)
    return if release.hotfix? && !force
    train.fixed_build_number? ? platform_run.bump_version_for_fixed_build_number! : platform_run.bump_version!
    platform_run.update!(last_commit: self)

    platform_run.release_platform.ordered_steps_until(platform_run.current_step_number).each do |step|
      next if release.hotfix? || step.manual_trigger_only?
      Triggers::StepRun.call(step, self, platform_run)
    end
  end

  def trigger_step_runs
    return unless applicable?

    release_platform_runs.have_not_submitted_production.each do |run|
      trigger_step_runs_for(run)
    end
  end

  def add_to_build_queue!(is_head_commit: true)
    return unless release.queue_commit?
    release.active_build_queue.add_commit!(self, can_apply: is_head_commit)
  end

  def trigger!
    return add_to_build_queue! if release.queue_commit?
    trigger_step_runs
  end

  def notification_params
    release.notification_params.merge(
      {
        commit_sha: short_sha,
        commit_url: url,
        commit_author: author_name,
        commit_author_email: author_email,
        commit_message: message,
        commit_timestamp: timestamp
      }
    )
  end
end
