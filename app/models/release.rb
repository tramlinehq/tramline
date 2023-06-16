# == Schema Information
#
# Table name: releases
#
#  id                       :uuid             not null, primary key
#  branch_name              :string           not null
#  completed_at             :datetime
#  original_release_version :string
#  release_version          :string
#  scheduled_at             :datetime
#  status                   :string           not null
#  stopped_at               :datetime
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  train_id                 :uuid             not null, indexed
#
class Release < ApplicationRecord
  has_paper_trail
  include AASM
  include Passportable
  include ActionView::Helpers::DateHelper
  using RefinedString

  self.implicit_order_column = :scheduled_at

  belongs_to :train
  has_one :release_metadata, dependent: :destroy, inverse_of: :release
  has_many :release_platform_runs, dependent: :destroy, inverse_of: :release
  has_many :commits, dependent: :destroy, inverse_of: :release
  has_many :pull_requests, dependent: :destroy, inverse_of: :release
  has_many :step_runs, through: :release_platform_runs

  scope :pending_release, -> { where.not(status: [:finished, :stopped]) }

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

  STATES = {
    created: "created",
    on_track: "on_track",
    post_release: "post_release",
    post_release_started: "post_release_started",
    post_release_failed: "post_release_failed",
    stopped: "stopped",
    finished: "finished"
  }

  enum status: STATES

  aasm safe_state_machine_params do
    state :created, initial: true
    state(*STATES.keys)

    event :start do
      after { start_release_platform_runs! }
      transitions from: [:created, :on_track], to: :on_track
    end

    event :start_post_release_phase, after_commit: -> { Releases::PostReleaseJob.perform_later(id) } do
      transitions from: [:on_track, :post_release_failed], to: :post_release_started, guard: :ready_to_be_finalized?
    end

    event :fail_post_release_phase do
      transitions from: :post_release_started, to: :post_release_failed
    end

    event :stop do
      before { self.stopped_at = Time.current }
      after { stop_runs }
      transitions to: :stopped
    end

    event :finish, after_commit: :on_finish do
      before { self.completed_at = Time.current }
      transitions from: :post_release_started, to: :finished
    end
  end

  # TODO: Remove this accessor, once the migration is complete
  attr_accessor :in_data_migration_mode

  before_create :set_version, unless: :in_data_migration_mode
  after_create :set_default_release_metadata, unless: :in_data_migration_mode
  after_create :create_train_runs, unless: :in_data_migration_mode
  after_commit -> { Releases::PreReleaseJob.perform_later(id) }, on: :create, unless: :in_data_migration_mode
  after_commit -> { Releases::FetchCommitLogJob.perform_later(id) }, on: :create, unless: :in_data_migration_mode

  attr_accessor :has_major_bump

  delegate :app, :pre_release_prs?, :vcs_provider, to: :train
  delegate :cache, to: Rails

  def self.pending_release?
    pending_release.exists?
  end

  def committable?
    created? || on_track?
  end

  def create_train_runs
    train.release_platforms.each do |release_platform|
      release_platform_runs.create!(
        code_name: "dummy",
        scheduled_at:,
        release_platform: release_platform
      )
    end
  end

  def start_release_platform_runs!
    ios_run&.start! unless ios_run&.finished?
    android_run&.start! unless android_run&.finished?
  end

  def ios_run
    release_platform_runs.where(release_platform: train.ios_train).first
  end

  def android_run
    release_platform_runs.where(release_platform: train.android_train).first
  end

  def stop_runs
    ios_run&.stop!
    android_run&.stop!
  end

  def set_version
    new_version = train.bump_release!(has_major_bump)
    self.release_version = new_version
    self.original_release_version = new_version
  end

  def set_default_release_metadata
    create_release_metadata!(locale: ReleaseMetadata::DEFAULT_LOCALE, release_notes: ReleaseMetadata::DEFAULT_RELEASE_NOTES)
  end

  def fetch_commit_log
    if previous_release.present?
      cache.fetch("app/#{app.id}/train/#{train.id}/releases/#{id}/commit_log", expires_in: 30.days) do
        vcs_provider.commit_log(previous_release.tag_name, train.working_branch)
      end
    end
  end

  def previous_release
    train.releases.where(status: "finished").order(completed_at: :desc).first
  end

  def tag_name
    "v#{release_version}"
  end

  def hotfix?
    return false unless on_track?
    release_version.to_semverish > original_release_version.to_semverish
  end

  def stoppable?
    created? || on_track?
  end

  def release_branch
    branch_name
  end

  def branch_url
    train.vcs_provider&.branch_url(train.app.config&.code_repository_name, branch_name)
  end

  def tag_url
    train.vcs_provider&.tag_url(train.app.config&.code_repository_name, tag_name)
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

  def ready_to_be_finalized?
    release_platform_runs.all?(&:finished?)
  end

  def finalize_phase_metadata
    {
      total_run_time: distance_of_time_in_words(created_at, completed_at),
      release_tag: tag_name,
      release_tag_url: tag_url,
      store_url: app.store_link
    }
  end

  def events(limit = nil)
    release_platform_runs
      .left_joins(step_runs: [deployment_runs: :staged_rollout])
      .pluck("release_platform_runs.id, step_runs.id, deployment_runs.id, staged_rollouts.id")
      .flatten
      .uniq
      .concat(commits.pluck(:id))
      .compact
      .push(id)
      .then { |ids| Passport.where(stampable_id: ids).order(event_timestamp: :desc).limit(limit) }
  end

  def last_commit
    commits.order(:created_at).last
  end

  def on_finish!
    event_stamp!(reason: :finished, kind: :success, data: {version: release_version})
  end
end
