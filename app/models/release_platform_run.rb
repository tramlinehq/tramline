# == Schema Information
#
# Table name: release_platform_runs
#
#  id                       :uuid             not null, primary key
#  branch_name              :string
#  code_name                :string           not null
#  commit_sha               :string
#  completed_at             :datetime
#  original_release_version :string
#  release_version          :string
#  scheduled_at             :datetime         not null
#  status                   :string           not null
#  stopped_at               :datetime
#  tag_name                 :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  release_id               :uuid
#  release_platform_id      :uuid             not null, indexed
#
class ReleasePlatformRun < ApplicationRecord
  has_paper_trail
  include AASM
  include Passportable
  include Taggable
  include ActionView::Helpers::DateHelper
  include Displayable
  using RefinedString

  # self.ignored_columns += %w[branch_name commit_sha original_release_version]
  self.implicit_order_column = :scheduled_at

  belongs_to :release_platform
  belongs_to :release
  has_many :step_runs, dependent: :destroy, inverse_of: :release_platform_run
  has_many :deployment_runs, through: :step_runs
  has_many :running_steps, through: :step_runs, source: :step
  has_many :passports, as: :stampable, dependent: :destroy

  scope :sequential, -> { order("release_platform_runs.created_at ASC") }
  scope :have_not_reached_production, -> { on_track.reject(&:production_release_happened?) }

  STAMPABLE_REASONS = %w[version_changed version_corrected finished]

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
      transitions from: [:created, :on_track], to: :stopped
    end

    event :finish, after_commit: :on_finish! do
      before { self.completed_at = Time.current }
      after { finish_release }
      transitions from: :on_track, to: :finished
    end
  end

  scope :pending_release, -> { where.not(status: [:finished, :stopped]) }

  delegate :all_commits, :original_release_version, to: :release
  delegate :steps, :train, :app, :platform, to: :release_platform

  def finish_release
    if release.ready_to_be_finalized?
      release.start_post_release_phase!
    else
      release.partially_finish!
    end
  end

  def correct_version!
    return if release_version.to_semverish.proper?

    version = corrected_release_version
    return unless version

    update!(release_version: version)

    event_stamp!(
      reason: :version_corrected,
      kind: :notice,
      data: {version: release_version, ongoing_version: version}
    )
  end

  # Ensure the version is up-to-date with the current ongoing release or the finished ongoing release
  def corrected_release_version
    return train.next_version if train.version_ahead?(release)
    train.ongoing_release.next_version if train.ongoing_release&.version_ahead?(release)
  end

  def bump_version!
    return unless version_bump_required?

    semverish = newest_release_version.to_semverish

    self.release_version = semverish.bump!(:patch).to_s if semverish.proper?
    self.release_version = semverish.bump!(:minor).to_s if semverish.partial?

    save!

    event_stamp!(
      reason: :version_changed,
      kind: :notice,
      data: {version: release_version}
    )
  end

  # Ensure the hotfix version is greater than the current upcoming release version
  def newest_release_version
    return release_version if release_version.to_semverish.proper?

    upcoming = train.upcoming_release
    return release_version unless upcoming&.version_ahead?(release)

    upcoming.release_version
  end

  def metadata_editable?
    on_track? && !started_store_release?
  end

  # FIXME: move to release and change it for proper movement UI
  def overall_movement_status
    steps.to_h do |step|
      run = last_commit&.run_for(step, self)
      [step, run.present? ? run.status_summary : {not_started: true}]
    end
  end

  def manually_startable_step?(step)
    return false if train.inactive?
    return false unless on_track?
    return false if upcoming_release_step?(step)
    return true if step.first? && step_runs_for(step).empty?
    return false if step.first?

    (next_step == step) && previous_step_run_for(step).success?
  end

  def upcoming_startable_step?(step)
    return false if train.inactive?
    return false unless on_track?

    (next_step == step) && previous_step_run_for(step).success? && upcoming_release_step?(step)
  end

  def upcoming_release_step?(step)
    step.release? && release.upcoming?
  end

  def step_runs_for(step)
    step_runs.where(step:)
  end

  def previous_step_run_for(step)
    last_run_for(step.previous)
  end

  def finalizable?
    may_finish? && finished_steps?
  end

  def next_step
    return steps.first if step_runs.empty?
    last_commit&.step_runs&.joins(:step)&.order(:step_number)&.last&.step&.next
  end

  def running_step?
    step_runs.on_track.exists?
  end

  def last_run_for(step)
    last_commit&.step_runs&.where(step: step)&.last
  end

  def current_step_number
    return if steps.blank?
    return 1 if running_steps.blank?
    running_steps.order(:step_number).last&.step_number
  end

  def last_commit
    step_runs.flat_map(&:commit).max_by(&:timestamp)
  end

  def finished_steps?
    last_commit&.step_runs&.where(release_platform_run: self)&.success&.size == steps.size
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

  def tag_url
    train.vcs_provider&.tag_url(app.config&.code_repository_name, tag_name)
  end

  def on_finish!
    ReleasePlatformRuns::CreateTagJob.perform_later(id) if app.cross_platform?
    event_stamp!(reason: :finished, kind: :success, data: {version: release_version})
    app.refresh_external_app
  end

  # recursively attempt to create a release tag until a unique one gets created
  # it *can* get expensive in the worst-case scenario, so ideally invoke this in a bg job
  def create_tag!(tag_name = base_tag_name)
    return if self.tag_name.present?
    train.create_tag!(tag_name, last_commit.commit_hash)
    update!(tag_name:)
  rescue Installations::Errors::TagReferenceAlreadyExists
    create_tag!(unique_tag_name(tag_name))
  end

  # Play Store does not have constraints around version name
  # App Store requires a higher version name than that of the previously approved version name
  # and so a version bump is required for iOS once the build has been approved as well
  def version_bump_required?
    return latest_deployed_store_release&.rollout_started? if release_platform.android?
    latest_deployed_store_release&.status&.in? [DeploymentRun::STATES[:rollout_started], DeploymentRun::STATES[:ready_to_release]]
  end

  def hotfix?
    return false unless on_track?
    (release_version.to_semverish > original_release_version.to_semverish) && production_release_happened?
  end

  def production_release_happened?
    step_runs
      .includes(:deployment_runs)
      .where(step: release_platform.release_step)
      .not_failed
      .any?(&:production_release_happened?)
  end

  def commit_applied?(commit)
    step_runs.exists?(commit: commit)
  end

  def commit_messages_before(step_run)
    all_commits
      .between(previous_successful_run_before(step_run), step_run)
      .pluck(:message)
  end

  def notification_params
    release.notification_params.merge(
      {
        release_version: release_version,
        app_platform: release_platform.platform
      }
    )
  end

  private

  def base_tag_name
    "v#{release_version}-#{platform}"
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
      .order(scheduled_at: :asc)
      .last
  end

  def previous_successful_run_before(step_run)
    step_runs
      .where(step: step_run.step)
      .where.not(id: step_run.id)
      .success
      .order(scheduled_at: :asc)
      .last
  end
end
