# == Schema Information
#
# Table name: release_platform_runs
#
#  id                  :uuid             not null, primary key
#  code_name           :string           not null
#  completed_at        :datetime
#  scheduled_at        :datetime         not null
#  status              :string           not null
#  stopped_at          :datetime
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  release_id          :uuid
#  release_platform_id :uuid             not null, indexed
#
class ReleasePlatformRun < ApplicationRecord
  has_paper_trail
  include AASM
  include Passportable
  include ActionView::Helpers::DateHelper
  using RefinedString

  self.ignored_columns += %w[branch_name commit_sha original_release_version release_version]
  self.implicit_order_column = :scheduled_at

  belongs_to :release_platform
  belongs_to :release
  has_many :pull_requests, dependent: :destroy, inverse_of: :release_platform_run
  has_many :step_runs, dependent: :destroy, inverse_of: :release_platform_run
  has_one :release_metadata, dependent: :destroy, inverse_of: :release_platform_run
  has_many :deployment_runs, through: :step_runs
  has_many :running_steps, through: :step_runs, source: :step
  has_many :passports, as: :stampable, dependent: :destroy

  STAMPABLE_REASONS = %w[finished]

  STATES = {
    created: "created",
    on_track: "on_track",
    stopped: "stopped",
    finished: "finished"
  }

  enum status: STATES

  aasm safe_state_machine_params do
    state :created, initial: true
    state(*STATES.keys)

    event :start do
      transitions from: [:created, :on_track], to: :on_track
    end

    event :stop do
      before { self.stopped_at = Time.current }
      transitions to: :stopped
    end

    event :finish, after_commit: :on_finish! do
      before { self.completed_at = Time.current }
      transitions from: :on_track, to: :finished
    end
  end

  scope :pending_release, -> { where.not(status: [:finished, :stopped]) }
  scope :released, -> { where(status: :finished).where.not(completed_at: nil) }
  attr_accessor :has_major_bump
  delegate :app, :pre_release_prs?, :vcs_provider, to: :release_platform
  delegate :cache, to: Rails
  delegate :release_branch, :branch_name, :last_commit, :commits, :tag_name, :tag_url, :original_release_version, :release_version, to: :release

  def metadata_editable?
    on_track? && !started_store_release?
  end

  def overall_movement_status
    all_steps.to_h do |step|
      run = last_commit&.run_for(step, self)
      [step, run.present? ? run.status_summary : {not_started: true}]
    end
  end

  def startable_step?(step)
    return false if release_platform.inactive?
    return false unless on_track?
    return true if step.first? && step_runs_for(step).empty?
    return false if step.first?

    (next_step == step) && previous_step_run_for(step).success?
  end

  def step_runs_for(step)
    step_runs.where(step:)
  end

  def previous_step_run_for(step)
    last_run_for(step.previous)
  end

  def self.pending_release?
    pending_release.exists?
  end

  def stoppable?
    created? || on_track?
  end

  def finalizable?
    may_finish? && ready_to_be_finalized?
  end

  def next_step
    return all_steps.first if step_runs.empty?
    step_runs.joins(:step).order(:step_number).last.step.next
  end

  def running_step?
    step_runs.on_track.exists?
  end

  def last_run_for(step)
    step_runs.where(step: step).last
  end

  def current_step_number
    return if all_steps.blank?
    return 1 if running_steps.blank?
    running_steps.order(:step_number).last.step_number
  end

  def finished_steps?
    commits.last&.step_runs&.where(release_platform_run: self)&.success&.size == all_steps.size
  end

  def latest_finished_step_runs
    step_runs
      .select("DISTINCT ON (step_id) *")
      .where(status: StepRun.statuses[:success])
      .order(:step_id, created_at: :desc)
  end

  def last_good_step_run
    step_runs
      .where(status: StepRun.statuses[:success])
      .joins(:step)
      .order(step_number: :desc, updated_at: :desc)
      .first
  end

  def final_build_artifact
    return unless finished?
    last_good_step_run&.build_artifact
  end

  def events(limit = nil)
    step_runs
      .left_joins(:commit, deployment_runs: :staged_rollout)
      .pluck("step_runs.id, deployment_runs.id, commits.id, staged_rollouts.id")
      .flatten
      .uniq
      .compact
      .push(id)
      .then { |ids| Passport.where(stampable_id: ids).order(event_timestamp: :desc).limit(limit) }
  end

  def all_steps
    release_platform.steps
  end

  def on_finish!
    event_stamp!(reason: :finished, kind: :success, data: {version: release_version})
    app.refresh_external_app

    release.start_post_release_phase! if release.ready_to_be_finalized?
  end

  # Play store does not have constraints around version name
  # App Store requires a higher version name than that of the previously approved version name
  # and so a version bump is required for iOS once the build has been approved as well
  def version_bump_required?
    return latest_deployed_store_release&.rollout_started? if release_platform.android?
    latest_deployed_store_release&.status&.in? [DeploymentRun::STATES[:rollout_started], DeploymentRun::STATES[:ready_to_release]]
  end

  def hotfix?
    return false unless on_track?
    (release_version.to_semverish > original_release_version.to_semverish) && production_release_started?
  end

  private

  def ready_to_be_finalized?
    finished_steps?
  end

  def started_store_release?
    latest_store_release.present?
  end

  def latest_store_release
    last_run_for(release_platform.release_step)
      &.deployment_runs
      &.not_failed
      &.find { |dr| dr.deployment.production_channel? }
  end

  def latest_deployed_store_release
    last_successful_run_for(release_platform.release_step)
      &.deployment_runs
      &.not_failed
      &.find { |dr| dr.deployment.production_channel? }
  end

  def last_successful_run_for(step)
    step_runs
      .where(step: step)
      .not_failed
      .last
  end

  def production_release_started?
    latest_deployed_store_release&.status&.in? [DeploymentRun::STATES[:rollout_started], DeploymentRun::STATES[:released]]
  end
end
