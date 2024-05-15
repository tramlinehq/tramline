# == Schema Information
#
# Table name: release_platform_runs
#
#  id                       :uuid             not null, primary key
#  branch_name              :string
#  code_name                :string           not null
#  commit_sha               :string
#  completed_at             :datetime
#  in_store_resubmission    :boolean          default(FALSE)
#  original_release_version :string
#  release_version          :string
#  scheduled_at             :datetime         not null
#  status                   :string           not null
#  stopped_at               :datetime
#  tag_name                 :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  last_commit_id           :uuid             indexed
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
  has_many :release_metadata, class_name: "ReleaseMetadata", dependent: :destroy, inverse_of: :release_platform_run
  has_many :step_runs, dependent: :destroy, inverse_of: :release_platform_run
  has_many :builds, dependent: :destroy, inverse_of: :release_platform_run
  has_many :play_store_submissions, dependent: :destroy
  has_many :app_store_submissions, dependent: :destroy
  has_many :external_builds, through: :step_runs
  has_many :deployment_runs, through: :step_runs
  has_many :running_steps, through: :step_runs, source: :step
  belongs_to :last_commit, class_name: "Commit", inverse_of: :release_platform_runs, optional: true

  scope :sequential, -> { order("release_platform_runs.created_at ASC") }
  scope :have_not_submitted_production, -> { on_track.reject(&:production_release_submitted?) }

  STAMPABLE_REASONS = %w[version_changed tag_created version_corrected finished stopped]

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

    event :stop, after_commit: -> { event_stamp!(reason: :stopped, kind: :notice, data: {version: release_version}) } do
      before { self.stopped_at = Time.current }
      transitions from: [:created, :on_track], to: :stopped
    end

    event :finish, after_commit: :on_finish! do
      before { self.completed_at = Time.current }
      after { finish_release }
      transitions from: :on_track, to: :finished
    end
  end

  after_create :set_default_release_metadata
  after_create :create_store_submission, if: -> { organization.product_v2? }
  scope :pending_release, -> { where.not(status: [:finished, :stopped]) }

  delegate :all_commits, :original_release_version, :hotfix?, :versioning_strategy, :organization, to: :release
  delegate :steps, :train, :app, :platform, :active_locales, :store_provider, :ios?, :android?, :default_locale, to: :release_platform

  def metadata_for(language)
    locale_tag = AppStores::Localizable.supported_locale_tag(language, :ios)
    release_metadata&.find_by(locale: locale_tag)
  end

  def store_submissions
    if android?
      play_store_submissions
    elsif ios?
      app_store_submissions
    else
      raise ArgumentError, "Unknown platform: #{platform}"
    end
  end

  def active_store_submission
    store_submissions.last
  end

  def previous_store_submissions
    return unless store_submissions.size > 1
    store_submissions.where.not(id: active_store_submission.id)
  end

  def create_store_submission
    if android?
      play_store_submissions.create!
    elsif ios?
      app_store_submissions.create!
    else
      raise ArgumentError, "Unknown platform: #{platform}"
    end
  end

  def latest_build?(build)
    builds.reorder("generated_at DESC").first == build
  end

  def check_release_health
    deployment_runs.each(&:check_release_health)
  end

  def release_metadatum
    release_metadata.where(locale: ReleaseMetadata::DEFAULT_LOCALES).first
  end

  def show_health?
    deployment_runs.any?(&:show_health?)
  end

  def unhealthy?
    latest_store_release&.unhealthy?
  end

  def failure?
    step_runs.last&.failure?
  end

  def set_default_release_metadata
    base = {
      release_notes: ReleaseMetadata::DEFAULT_RELEASE_NOTES,
      release_id:
    }

    if active_locales.present?
      data = active_locales.map { |locale| base.merge(locale.to_h) }
      release_metadata.insert_all!(data)
      return
    end

    locale = default_locale || ReleaseMetadata::DEFAULT_LOCALE
    release_metadata.create!(base.merge(locale: locale, default_locale: true))
  end

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
    return train.next_version if train.version_ahead?(self)
    return train.ongoing_release.next_version if train.ongoing_release&.version_ahead?(self) && !release.hotfix?
    train.hotfix_release.next_version if train.hotfix_release&.version_ahead?(self)
  end

  def bump_version_for_fixed_build_number!
    return unless train.fixed_build_number?

    # bump the build number if it is the first commit of the release or it is patch fix on the release
    if release.all_commits.size == 1
      app.bump_build_number!
    else
      if version_bump_required?
        app.bump_build_number!
        self.in_store_resubmission = true
      end
      self.release_version = release_version.to_semverish.bump!(:patch, strategy: versioning_strategy).to_s
      event_stamp!(
        reason: :version_changed,
        kind: :notice,
        data: {version: release_version}
      )
    end

    save!
  end

  def bump_version!
    return unless version_bump_required?

    self.in_store_resubmission = true

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

  # Ensure the patch fix version is greater than the current upcoming release version
  def newest_release_version
    return release_version if release_version.to_semverish.proper?

    upcoming = train.upcoming_release
    return release_version unless upcoming&.version_ahead?(self)

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

  def allow_blocked_step?
    Flipper.enabled?(:allow_blocked_step, self)
  end

  def manually_startable_step?(step)
    return false if train.inactive?
    return false unless on_track?
    return false if last_commit.blank?
    return false if ongoing_release_step?(step) && train.hotfix_release.present? && !allow_blocked_step?
    return true if (hotfix? || patch_fix?) && last_commit.run_for(step, self).blank?
    return false if upcoming_release_step?(step)
    return true if step.first? && step_runs_for(step).empty?
    return false if step.first?

    (next_step == step) && previous_step_run_for(step).success?
  end

  def step_start_blocked?(step)
    return false if train.inactive?
    return false unless on_track?
    return false if last_commit.blank?
    return false if allow_blocked_step?
    return true if train.hotfix_release.present? && train.hotfix_release != release && step.release?

    (next_step == step) && previous_step_run_for(step)&.success? && upcoming_release_step?(step)
  end

  def upcoming_release_step?(step)
    step.release? && release.upcoming?
  end

  def ongoing_release_step?(step)
    step.release? && release.ongoing?
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
    return steps.first if step_runs.empty? || last_commit.blank?
    return steps.first if last_commit.step_runs_for(self).empty?
    last_commit.step_runs_for(self).joins(:step).order(:step_number).last.step.next
  end

  def running_step?
    step_runs.on_track.exists?
  end

  def last_run_for(step)
    return if last_commit.blank?
    last_commit.step_runs_for(self).where(step: step).sequential.last
  end

  def current_step_number
    return if steps.blank?
    return steps.minimum(:step_number) if running_steps.blank?
    running_steps.order(:step_number).last.step_number
  end

  def finished_steps?
    return false if release_platform.release_step.blank?
    return false if last_commit.blank?

    last_commit.run_for(release_platform.release_step, self)&.success?
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

  def tag_url
    train.vcs_provider&.tag_url(app.config&.code_repository_name, tag_name)
  end

  def on_finish!
    ReleasePlatformRuns::CreateTagJob.perform_later(id) if train.tag_platform_at_release_end?
    event_stamp!(reason: :finished, kind: :success, data: {version: release_version})
    app.refresh_external_app
  end

  # recursively attempt to create a release tag until a unique one gets created
  # it *can* get expensive in the worst-case scenario, so ideally invoke this in a bg job
  def create_tag!(input_tag_name = base_tag_name)
    train.create_tag!(input_tag_name, last_commit.commit_hash)
    update!(tag_name: input_tag_name)
    event_stamp!(reason: :tag_created, kind: :notice, data: {tag: tag_name})
  rescue Installations::Errors::TagReferenceAlreadyExists
    create_tag!(unique_tag_name(input_tag_name))
  end

  # Play Store does not have constraints around version name
  # App Store requires a higher version name than that of the previously approved version name
  # and so a version bump is required for iOS once the build has been approved as well
  #
  # Additionally, we don't bump versions until commits since the previous store version have also reached store
  # --
  # Example,
  # Current version: 16.72 (1% on store)
  # Patch fix commit: bump to 16.73
  # 16.73 never reaches store
  # Patch fix commit: no bump required
  # --
  def version_bump_required?
    store_release = latest_deployed_store_release
    store_release&.status&.in?(DeploymentRun::READY_STATES) && store_release.step_run.basic_build_version == release_version
  end

  def patch_fix?
    on_track? && in_store_resubmission?
  end

  def release_step_started?
    step_runs_for(release_platform.release_step).present?
  end

  def production_release_happened?
    step_runs
      .includes(:deployment_runs)
      .where(step: release_platform.release_step)
      .not_failed
      .any?(&:production_release_happened?)
  end

  def production_release_submitted?
    step_runs
      .includes(:deployment_runs)
      .where(step: release_platform.release_step)
      .not_failed
      .any?(&:production_release_submitted?)
  end

  def commit_applied?(commit)
    step_runs.exists?(commit: commit)
  end

  def previous_successful_run_before(step_run)
    step_runs
      .where(step: step_run.step)
      .where.not(id: step_run.id)
      .success
      .order(scheduled_at: :asc)
      .last
  end

  def commits_between(older_step_run, newer_step_run)
    all_commits.between(older_step_run, newer_step_run)
  end

  def notification_params
    release.notification_params.merge(
      {
        release_version: release_version,
        app_platform: release_platform.platform,
        release_notes: release_metadatum&.release_notes
      }
    )
  end

  def store_releases
    deployment_runs.reached_production.sort_by(&:scheduled_at).reverse
  end

  def store_submitted_releases
    deployment_runs.reached_submission.sort_by(&:scheduled_at).reverse
  end

  private

  def base_tag_name
    return "v#{release_version}-hotfix-#{platform}" if hotfix?
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
end
