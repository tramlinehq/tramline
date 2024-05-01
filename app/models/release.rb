# == Schema Information
#
# Table name: releases
#
#  id                       :uuid             not null, primary key
#  branch_name              :string           not null
#  completed_at             :datetime
#  hotfixed_from            :uuid
#  internal_notes           :jsonb
#  is_automatic             :boolean          default(FALSE)
#  new_hotfix_branch        :boolean          default(FALSE)
#  original_release_version :string
#  release_type             :string           not null
#  scheduled_at             :datetime
#  status                   :string           not null
#  stopped_at               :datetime
#  tag_name                 :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  release_pilot_id         :uuid
#  train_id                 :uuid             not null, indexed
#
class Release < ApplicationRecord
  has_paper_trail
  include AASM
  include Passportable
  include Taggable
  include Versionable
  include Displayable
  include Linkable
  include ActionView::Helpers::DateHelper

  using RefinedString

  self.implicit_order_column = :scheduled_at
  self.ignored_columns += ["release_version"]

  TERMINAL_STATES = [:finished, :stopped, :stopped_after_partial_finish]
  DEFAULT_INTERNAL_NOTES = {
    "ops" => [
      {"insert" => "Write your internal notes, tasks lists, description, pretty much anything really."},
      {"attributes" => {"align" => "center"}, "insert" => "\n\n"},
      {"insert" => "Anything interesting about this release you want to remember?"},
      {"attributes" => {"align" => "center"}, "insert" => "\n"},
      {"insert" => "Just "},
      {"attributes" => {"bold" => true}, "insert" => "dump"},
      {"insert" => " it here."},
      {"attributes" => {"align" => "center"}, "insert" => "\n\n"},
      {"insert" => "You can use lists, styles and emojis and a whole bunch more! ⚡️✈️🌈"},
      {"attributes" => {"align" => "center"}, "insert" => "\n"}
    ]
  }

  belongs_to :train
  belongs_to :hotfixed_from, class_name: "Release", optional: true, foreign_key: "hotfixed_from", inverse_of: :hotfixed_releases
  belongs_to :release_pilot, class_name: "Accounts::User", optional: true
  has_one :scheduled_release, dependent: :destroy
  has_one :release_changelog, dependent: :destroy, inverse_of: :release
  has_many :release_platform_runs, -> { sequential }, dependent: :destroy, inverse_of: :release
  has_many :release_metadata, through: :release_platform_runs
  has_many :all_commits, dependent: :destroy, inverse_of: :release, class_name: "Commit"
  has_many :pull_requests, dependent: :destroy, inverse_of: :release
  has_many :step_runs, through: :release_platform_runs
  has_many :deployment_runs, through: :step_runs
  has_many :build_queues, dependent: :destroy
  has_one :active_build_queue, -> { active }, class_name: "BuildQueue", inverse_of: :release, dependent: :destroy
  has_many :hotfixed_releases, class_name: "Release", inverse_of: :hotfixed_from, dependent: :destroy

  scope :completed, -> { where(status: TERMINAL_STATES) }
  scope :pending_release, -> { where.not(status: TERMINAL_STATES) }
  scope :released, -> { where(status: :finished).where.not(completed_at: nil) }
  scope :sequential, -> { order("releases.scheduled_at DESC") }

  STAMPABLE_REASONS = %w[
    created
    release_branch_created
    kickoff_pr_succeeded
    version_changed
    finalizing
    pre_release_pr_not_creatable
    pull_request_not_mergeable
    post_release_pr_succeeded
    backmerge_pr_created
    pr_merged
    backmerge_failure
    vcs_release_created
    finalize_failed
    stopped
    finished
  ]

  # TODO: deprecate this
  STAMPABLE_REASONS.concat(["status_changed"])

  STATES = {
    created: "created",
    on_track: "on_track",
    post_release: "post_release",
    post_release_started: "post_release_started",
    post_release_failed: "post_release_failed",
    stopped: "stopped",
    finished: "finished",
    partially_finished: "partially_finished",
    stopped_after_partial_finish: "stopped_after_partial_finish"
  }

  enum status: STATES
  enum release_type: {
    hotfix: "hotfix",
    release: "release"
  }

  aasm safe_state_machine_params do
    state :created, initial: true
    state(*STATES.keys)

    event :start, after_commit: :on_start! do
      after { start_release_platform_runs! }
      transitions from: [:created, :on_track], to: :on_track
      transitions from: [:partially_finished], to: :partially_finished
    end

    event :start_post_release_phase, after_commit: -> { Releases::PostReleaseJob.perform_later(id, force_finalize) } do
      transitions from: [:on_track, :post_release_failed, :partially_finished], to: :post_release_started, guard: :ready_to_be_finalized?
    end

    event :fail_post_release_phase do
      transitions from: :post_release_started, to: :post_release_failed
    end

    event :partially_finish do
      transitions from: :on_track, to: :partially_finished
    end

    event :stop, after_commit: :on_stop! do
      before { self.stopped_at = Time.current }
      after { stop_runs }
      transitions from: :partially_finished, to: :stopped_after_partial_finish
      transitions from: [:created, :on_track, :post_release_started, :post_release_failed], to: :stopped
    end

    event :finish, after_commit: :on_finish! do
      before { self.completed_at = Time.current }
      transitions from: :post_release_started, to: :finished
    end
  end

  before_create :set_version
  before_create :set_internal_notes
  after_create :create_platform_runs
  after_create :create_active_build_queue, if: -> { train.build_queue_enabled? }
  after_commit -> { Releases::PreReleaseJob.perform_later(id) }, on: :create
  after_commit -> { Releases::FetchCommitLogJob.perform_later(id) }, on: :create
  after_commit -> { create_stamp!(data: {version: original_release_version}) }, on: :create
  after_create_commit -> { RefreshReportsJob.perform_later(hotfixed_from.id) }, if: -> { hotfix? && hotfixed_from.present? }

  attr_accessor :has_major_bump, :force_finalize, :hotfix_platform, :custom_version

  delegate :versioning_strategy, to: :train
  delegate :app, :vcs_provider, :release_platforms, :notify!, :continuous_backmerge?, to: :train
  delegate :platform, :organization, to: :app

  def self.pending_release?
    pending_release.exists?
  end

  def self.for_branch(branch_name) = find_by(branch_name:)

  def index_score
    return if hotfix?
    return unless finished?

    rollout_duration = 0
    stability_duration = 0
    rollout_fixes = 0

    submitted_at = deployment_runs.map(&:submitted_at).compact.min
    rollout_started_at = deployment_runs.map(&:release_started_at).compact.min
    max_store_versions = deployment_runs.reached_production.group_by(&:platform).transform_values(&:size).values.max

    rollout_fixes = max_store_versions - 1 if max_store_versions.present?
    rollout_duration = ActiveSupport::Duration.build(completed_at - rollout_started_at).in_days if rollout_started_at.present?
    stability_duration = ActiveSupport::Duration.build(submitted_at - scheduled_at).in_days if submitted_at.present?

    params = {
      hotfixes: all_hotfixes.size,
      rollout_fixes:,
      rollout_duration:,
      duration: duration.in_days,
      stability_duration:,
      stability_changes: stability_commits.count
    }

    train.release_index&.score(**params)
  end

  def unhealthy?
    release_platform_runs.any?(&:unhealthy?)
  end

  def show_health?
    return true if ongoing? || partially_finished?
    return true if finished? && release_platform_runs.any?(&:show_health?)
    false
  end

  def finish_after_partial_finish!
    with_lock do
      return unless partially_finished?
      release_platform_runs.pending_release.map(&:stop!)
      start_post_release_phase!
    end
  end

  def backmerge_failure_count
    return 0 unless continuous_backmerge?
    all_commits.size - backmerge_prs.size - 1
  end

  def backmerge_prs
    pull_requests.ongoing
  end

  def post_release_prs
    pull_requests.post_release
  end

  def pre_release_prs
    pull_requests.pre_release
  end

  def mid_release_prs
    pull_requests.mid_release.order(Arel.sql("CASE WHEN state = 'open' THEN 1 ELSE 2 END"))
  end

  def duration
    return unless finished?
    ActiveSupport::Duration.build(completed_at - scheduled_at)
  end

  def all_store_step_runs
    deployment_runs
      .reached_production
      .map(&:step_run)
      .sort_by(&:updated_at)
  end

  def unmerged_commits
    all_commits.where(backmerge_failure: true)
  end

  def stability_commits
    all_commits.where.not(id: first_commit&.id)
  end

  def compare_url
    vcs_provider.compare_url(train.working_branch, release_branch)
  end

  def version_ahead?(platform_run)
    return false if self == platform_run.release
    release_version.to_semverish >= platform_run.release_version.to_semverish
  end

  def create_active_build_queue
    build_queues.create(scheduled_at: (Time.current + train.build_queue_wait_time), is_active: true)
  end

  def applied_commits
    return all_commits if active_build_queue.blank?
    all_commits.where.not(build_queue_id: active_build_queue.id).or(all_commits.where(build_queue_id: nil))
  end

  def committable?
    created? || on_track? || partially_finished?
  end

  def active?
    !status.to_sym.in?(TERMINAL_STATES)
  end

  def queue_commit?
    active_build_queue.present? && release_changes?
  end

  def release_changes?
    all_commits.size > 1
  end

  def stoppable?
    may_stop?
  end

  def end_time
    completed_at || stopped_at
  end

  def fetch_commit_log
    # release branch for a new release may not exist on vcs provider since pre release job runs in parallel to fetch commit log job
    target_branch = train.working_branch
    if upcoming?
      ongoing_head = train.ongoing_release.first_commit
      source_commitish, from_ref = ongoing_head.commit_hash, ongoing_head.short_sha
    elsif hotfix?
      return if new_hotfix_branch? # there is no diff between the hotfixed from tag and the new hotfix release branch
      source_commitish = from_ref = hotfixed_from.end_ref
      target_branch = hotfixed_from.release_branch
    else
      source_commitish = from_ref = previous_release&.end_ref
    end

    return if source_commitish.blank?

    create_release_changelog(
      commits: vcs_provider.commit_log(source_commitish, target_branch),
      from_ref:
    )
  end

  def end_ref
    tag_name || last_commit.short_sha
  end

  def release_version
    release_platform_runs.pluck(:release_version).map(&:to_semverish).max.to_s
  end

  alias_method :version_current, :release_version

  def release_branch
    branch_name
  end

  # recursively attempt to create a release until a unique one gets created
  # it *can* get expensive in the worst-case scenario, so ideally invoke this in a bg job
  def create_release!(input_tag_name = base_tag_name)
    return unless train.tag_releases?
    return if tag_name.present?
    train.create_release!(release_branch, input_tag_name)
    update!(tag_name: input_tag_name)
    event_stamp!(reason: :vcs_release_created, kind: :notice, data: {provider: vcs_provider.display, tag: tag_name})
  rescue Installations::Errors::TagReferenceAlreadyExists, Installations::Errors::TaggedReleaseAlreadyExists
    create_release!(unique_tag_name(input_tag_name))
  end

  def branch_url
    train.vcs_provider&.branch_url(app.config&.code_repository_name, release_branch)
  end

  def tag_url
    train.vcs_provider&.tag_url(app.config&.code_repository_name, tag_name)
  end

  def pull_requests_url(open = false)
    train.vcs_provider&.pull_requests_url(app.config&.code_repository_name, branch_name, open:)
  end

  def metadata_editable?
    release_platform_runs.any?(&:metadata_editable?)
  end

  def release_step_started?
    release_platform_runs.any?(&:release_step_started?)
  end

  class PreReleaseUnfinishedError < StandardError; end

  def close_pre_release_prs
    return if pull_requests.pre_release.blank?

    pull_requests.pre_release.each do |pr|
      created_pr = train.vcs_provider.get_pr(pr.number)

      if created_pr[:state].in? %w[open opened]
        raise PreReleaseUnfinishedError, "Pre-release pull request is not merged yet."
      else
        pr.close!
      end
    end
  end

  def patch_fix?
    return false unless committable?
    release_platform_runs.any?(&:patch_fix?)
  end

  def ready_to_be_finalized?
    release_platform_runs.all? { |prun| prun.finished? || prun.stopped? }
  end

  def finalize_phase_metadata
    {
      total_run_time: distance_of_time_in_words(created_at, completed_at),
      release_tag: tag_name,
      release_tag_url: tag_url,
      store_url: (app.store_link unless app.cross_platform?),
      final_artifact_url: (release_platform_runs.first&.final_build_artifact&.download_url unless app.cross_platform?)
    }
  end

  def live_release_link
    return if Rails.env.test?
    release_url(id, link_params)
  end

  def notification_params
    train.notification_params.merge(
      {
        release_branch: release_branch,
        release_branch_url: branch_url,
        release_url: live_release_link,
        release_version: release_version,
        is_release_unhealthy: unhealthy?
      }
    )
  end

  def last_commit
    all_commits.last
  end

  def first_commit
    all_commits.first
  end

  def latest_commit_hash(sha_only: true)
    vcs_provider.branch_head_sha(release_branch, sha_only:)
  end

  def upcoming?
    train.upcoming_release == self
  end

  def ongoing?
    train.ongoing_release == self
  end

  def retrigger_for_hotfix?
    hotfix? && !new_hotfix_branch?
  end

  def hotfixes
    app.releases.hotfix.where(hotfixed_from: self)
  end

  def all_hotfixes
    query = <<~SQL.squish
              WITH RECURSIVE hotfix_tree AS (
          SELECT *
          FROM releases
          WHERE hotfixed_from = :id
          AND release_type = 'hotfix'
          UNION ALL
          SELECT r.*
          FROM releases r
          JOIN hotfix_tree h ON r.hotfixed_from = h.id
          WHERE r.release_type = 'hotfix'
      )
      SELECT *
      FROM hotfix_tree
      ORDER BY scheduled_at DESC;
    SQL

    Release.find_by_sql [query, {id: id}]
  end

  private

  def base_tag_name
    tag = "v#{release_version}"
    tag += "-hotfix" if hotfix?
    tag += "-" + train.tag_suffix if train.tag_suffix.present?
    tag
  end

  def create_platform_runs
    release_platforms.each do |release_platform|
      next if hotfix? && hotfix_platform.present? && hotfix_platform != release_platform.platform
      release_platform_runs.create!(
        code_name: Haikunator.haikunate(100),
        scheduled_at:,
        release_version: original_release_version,
        release_platform: release_platform
      )
    end
  end

  def start_release_platform_runs!
    release_platform_runs.each do |run|
      run.start! unless run.finished?
    end
  end

  def stop_runs
    release_platform_runs.each do |run|
      run.stop! if run.may_stop?
    end
  end

  def set_version
    if custom_version.present?
      self.original_release_version = custom_version
      return
    end

    self.original_release_version = if hotfix?
      train.hotfix_from&.next_version(patch_only: hotfix?)
    else
      (train.ongoing_release.presence || train.hotfix_release.presence || train).next_version(major_only: has_major_bump)
    end
  end

  def set_internal_notes
    self.internal_notes = DEFAULT_INTERNAL_NOTES.to_json
  end

  def previous_release
    train.releases.where(status: "finished").reorder(completed_at: :desc).first
  end

  def on_start!
    notify!("New release has commenced!", :release_started, notification_params) if all_commits.size.eql?(1)
  end

  def on_stop!
    update_train_version if stopped_after_partial_finish?
    event_stamp!(reason: :stopped, kind: :notice, data: {version: release_version})
    notify!("Release has stopped!", :release_stopped, notification_params)
  end

  def on_finish!
    update_train_version
    event_stamp!(reason: :finished, kind: :success, data: {version: release_version})
    notify!("Release has finished!", :release_ended, notification_params.merge(finalize_phase_metadata))
    RefreshReportsJob.perform_later(id)
  end

  def update_train_version
    train.update!(version_current: release_version)
  end
end
