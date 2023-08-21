# == Schema Information
#
# Table name: releases
#
#  id                       :uuid             not null, primary key
#  branch_name              :string           not null
#  completed_at             :datetime
#  is_automatic             :boolean          default(FALSE)
#  original_release_version :string
#  release_version          :string
#  scheduled_at             :datetime
#  status                   :string           not null
#  stopped_at               :datetime
#  tag_name                 :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  train_id                 :uuid             not null, indexed
#
class Release < ApplicationRecord
  has_paper_trail
  include AASM
  include Passportable
  include Taggable
  include ActionView::Helpers::DateHelper
  include Rails.application.routes.url_helpers
  using RefinedString

  self.implicit_order_column = :scheduled_at
  # self.ignored_columns += ["release_version"]

  belongs_to :train
  has_one :release_metadata, dependent: :destroy, inverse_of: :release
  has_one :release_changelog, dependent: :destroy, inverse_of: :release
  has_many :release_platform_runs, -> { sequential }, dependent: :destroy, inverse_of: :release
  has_many :commits, dependent: :destroy, inverse_of: :release
  has_many :pull_requests, dependent: :destroy, inverse_of: :release
  has_many :step_runs, through: :release_platform_runs
  has_many :build_queues, dependent: :destroy
  has_one :active_build_queue, -> { active }, class_name: "BuildQueue", inverse_of: :release, dependent: :destroy

  scope :pending_release, -> { where.not(status: [:finished, :stopped, :stopped_after_partial_finish]) }
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
    finalize_failed
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

  aasm safe_state_machine_params do
    state :created, initial: true
    state(*STATES.keys)

    event :start, after_commit: :on_start! do
      after { start_release_platform_runs! }
      transitions from: [:created, :on_track], to: :on_track
      transitions from: [:partially_finished], to: :partially_finished
    end

    event :start_post_release_phase, after_commit: -> { Releases::PostReleaseJob.perform_later(id) } do
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
  after_create :set_default_release_metadata
  after_create :create_platform_runs
  after_create :create_active_build_queue, if: -> { train.build_queue_enabled? }
  after_commit -> { Releases::PreReleaseJob.perform_later(id) }, on: :create
  after_commit -> { Releases::FetchCommitLogJob.perform_later(id) }, on: :create

  attr_accessor :has_major_bump

  delegate :app, :pre_release_prs?, :vcs_provider, :release_platforms, :notify!, to: :train

  def self.pending_release?
    pending_release.exists?
  end

  def create_active_build_queue
    build_queues.create(scheduled_at: train.build_queue_wait_time, is_active: true)
  end

  def active_commits
    return commits if active_build_queue.blank?
    commits.where.not(build_queue_id: active_build_queue.id).or(commits.where(build_queue_id: nil))
  end

  def committable?
    created? || on_track? || partially_finished?
  end

  def stoppable?
    may_stop?
  end

  def fetch_commit_log
    if previous_release.present?
      create_release_changelog(
        commits: vcs_provider.commit_log(previous_release.tag_name, train.working_branch),
        from_ref: previous_release.tag_name
      )
    end
  end

  def release_version
    release_platform_runs.pluck(:release_version).map(&:to_semverish).max.to_s
  end

  def release_branch
    branch_name
  end

  # recursively attempt to create a release until a unique one gets created
  # it *can* get expensive in the worst-case scenario, so ideally invoke this in a bg job
  def create_release!(tag_name = base_tag_name)
    return if self.tag_name.present?
    train.create_release!(release_branch, tag_name)
    update!(tag_name:)
  rescue Installations::Errors::TagReferenceAlreadyExists, Installations::Errors::TaggedReleaseAlreadyExists
    create_release!(unique_tag_name(tag_name))
  end

  def branch_url
    train.vcs_provider&.branch_url(app.config&.code_repository_name, release_branch)
  end

  def tag_url
    train.vcs_provider&.tag_url(app.config&.code_repository_name, tag_name)
  end

  def metadata_editable?
    release_platform_runs.any?(&:metadata_editable?)
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

  def version_bump_required?
    release_platform_runs.any?(&:version_bump_required?)
  end

  def hotfix?
    return false unless committable?
    release_platform_runs.any?(&:hotfix?)
  end

  def ready_to_be_finalized?
    release_platform_runs.all?(&:finished?)
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

    if Rails.env.development?
      release_url(self, host: ENV["HOST_NAME"], protocol: "https", port: ENV["PORT_NUM"])
    else
      release_url(self, host: ENV["HOST_NAME"], protocol: "https")
    end
  end

  def notification_params
    train.notification_params.merge(
      {
        release_branch: release_branch,
        release_branch_url: branch_url,
        release_url: live_release_link,
        release_notes: release_metadata&.release_notes
      }
    )
  end

  def events(limit = nil)
    release_platform_runs
      .left_joins(step_runs: [:commit, [deployment_runs: :staged_rollout]])
      .pluck("commits.id, release_platform_runs.id, step_runs.id, deployment_runs.id, staged_rollouts.id")
      .flatten
      .uniq
      .compact
      .push(id)
      .then { |ids| Passport.where(stampable_id: ids).order(event_timestamp: :desc).limit(limit) }
  end

  def last_commit
    commits.order(:created_at).last
  end

  def latest_commit_hash
    vcs_provider.branch_head_sha(release_branch)
  end

  private

  def base_tag_name
    "v#{release_version}"
  end

  def create_platform_runs
    release_platforms.each do |release_platform|
      release_platform_runs.create!(
        code_name: Haikunator.haikunate(100),
        scheduled_at:,
        release_version: train.version_current,
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
    new_version = train.bump_release!(has_major_bump)
    self.original_release_version = new_version
  end

  def set_default_release_metadata
    create_release_metadata!(locale: ReleaseMetadata::DEFAULT_LOCALE, release_notes: ReleaseMetadata::DEFAULT_RELEASE_NOTES)
  end

  def previous_release
    train.releases.where(status: "finished").order(completed_at: :desc).first
  end

  def on_start!
    notify!("New release has commenced!", :release_started, notification_params) if commits.size.eql?(1)
  end

  def on_stop!
    notify!("Release has stopped!", :release_stopped, notification_params)
  end

  def on_finish!
    event_stamp!(reason: :finished, kind: :success, data: {version: release_version})
    notify!("Release has finished!", :release_ended, notification_params.merge(finalize_phase_metadata))
  end
end
