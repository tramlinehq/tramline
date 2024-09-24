# == Schema Information
#
# Table name: release_platform_runs
#
#  id                    :uuid             not null, primary key
#  code_name             :string           not null
#  completed_at          :datetime
#  config                :jsonb
#  in_store_resubmission :boolean          default(FALSE)
#  play_store_blocked    :boolean          default(FALSE)
#  release_version       :string
#  scheduled_at          :datetime         not null
#  status                :string           not null
#  stopped_at            :datetime
#  tag_name              :string
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  last_commit_id        :uuid             indexed
#  release_id            :uuid
#  release_platform_id   :uuid             not null, indexed
#
class ReleasePlatformRun < ApplicationRecord
  has_paper_trail
  include AASM
  include Passportable
  include Taggable
  include ActionView::Helpers::DateHelper
  include Displayable
  using RefinedString

  self.ignored_columns += %w[branch_name commit_sha original_release_version]
  self.implicit_order_column = :scheduled_at

  belongs_to :release_platform
  belongs_to :release
  belongs_to :last_commit, class_name: "Commit", inverse_of: :release_platform_runs, optional: true
  has_many :release_metadata, class_name: "ReleaseMetadata", dependent: :destroy, inverse_of: :release_platform_run
  has_many :workflow_runs, dependent: :destroy
  has_many :builds, dependent: :destroy, inverse_of: :release_platform_run
  has_many :internal_builds, -> { internal.ready }, class_name: "Build", dependent: :destroy, inverse_of: :release_platform_run
  has_many :rc_builds, -> { release_candidate.ready.reorder("generated_at DESC") }, class_name: "Build", dependent: :destroy, inverse_of: :release_platform_run
  has_many :pre_prod_releases, dependent: :destroy
  has_many :internal_releases, dependent: :destroy
  has_many :beta_releases, dependent: :destroy
  has_many :store_submissions, dependent: :destroy
  has_many :production_releases, dependent: :destroy
  has_one :inflight_production_release, -> { inflight }, class_name: "ProductionRelease", inverse_of: :release_platform_run, dependent: :destroy
  has_one :active_production_release, -> { active }, class_name: "ProductionRelease", inverse_of: :release_platform_run, dependent: :destroy
  has_one :finished_production_release, -> { finished }, class_name: "ProductionRelease", inverse_of: :release_platform_run, dependent: :destroy
  has_many :store_rollouts, dependent: :destroy
  has_many :production_store_rollouts, -> { production }, class_name: "StoreRollout", dependent: :destroy, inverse_of: :release_platform_run
  has_many :production_store_submissions, -> { production }, class_name: "StoreSubmission", dependent: :destroy, inverse_of: :release_platform_run

  # NOTE: deprecated after v2
  has_many :step_runs, dependent: :destroy, inverse_of: :release_platform_run
  has_many :external_builds, through: :step_runs
  has_many :deployment_runs, through: :step_runs
  has_many :running_steps, through: :step_runs, source: :step

  scope :sequential, -> { order("release_platform_runs.created_at ASC") }
  scope :have_not_submitted_production, -> { on_track.reject(&:production_release_submitted?) }

  STAMPABLE_REASONS = %w[version_changed tag_created version_corrected finished stopped]

  STATES = {
    created: "created",
    on_track: "on_track",
    stopped: "stopped",
    finished: "finished"
  }

  enum :status, STATES

  before_create :set_config, if: -> { release.is_v2? }
  after_create :set_default_release_metadata
  scope :pending_release, -> { where.not(status: [:finished, :stopped]) }

  delegate :all_commits, :original_release_version, :hotfix?, :versioning_strategy, :organization, :release_branch, to: :release
  delegate :steps, :train, :app, :platform, :active_locales, :store_provider, :ios?, :android?, :default_locale, :ci_cd_provider, to: :release_platform

  def start!
    with_lock do
      return unless created?
      update!(status: STATES[:on_track])
    end
  end

  def stop!
    with_lock do
      return if finished?
      update!(status: STATES[:stopped], stopped_at: Time.current)
    end

    event_stamp!(reason: :stopped, kind: :notice, data: {version: release_version})
  end

  def finish!
    with_lock do
      return unless on_track?
      update!(status: STATES[:finished], completed_at: Time.current)
    end
  end

  def active?
    STATES.slice(:created, :on_track).value?(status)
  end

  def metadata_for(language, platform)
    locale_tag = AppStores::Localizable.supported_locale_tag(language, platform)
    release_metadata&.find_by(locale: locale_tag)
  end

  def conf
    ReleaseConfig::Platform.new(config)
  end

  def ready_for_beta_release?
    return true if release.hotfix?
    return true if conf.only_beta_release?
    latest_internal_release(finished: true).present?
  end

  def production_release_active?
    active_production_release.present?
  end

  def latest_beta_release(finished: false)
    (finished ? beta_releases.finished : beta_releases).order(created_at: :desc).first
  end

  # TODO: [V2] eager loading here is too expensive
  def latest_internal_release(finished: false)
    (finished ? internal_releases.finished : internal_releases)
      .includes(:commit, :store_submissions, triggered_workflow_run: {build: [:commit, :artifact]}, release_platform_run: [:release])
      .order(created_at: :desc)
      .first
  end

  def latest_production_release
    production_releases.order(created_at: :desc).first
  end

  def inflight_store_rollout
    inflight_production_release&.store_rollout
  end

  def active_store_rollout
    active_production_release&.store_rollout
  end

  def finished_store_rollout
    finished_production_release&.store_rollout
  end

  def older_beta_releases
    beta_releases.order(created_at: :desc).offset(1)
  end

  # TODO: [V2] eager loading here is too expensive
  def older_internal_releases
    internal_releases
      .order(created_at: :desc)
      .includes(:commit, :store_submissions, triggered_workflow_run: {build: [:commit, :artifact]}, release_platform_run: [:release])
      .offset(1)
  end

  def older_production_releases
    production_releases.stale.order(created_at: :desc)
  end

  def older_production_store_rollouts
    older_production_releases.includes(store_submission: :store_rollout).filter_map(&:store_rollout)
  end

  def latest_rc_build?(build)
    rc_builds.first == build
  end

  def available_rc_builds(after: nil)
    builds = rc_builds
      .left_joins(:production_releases)
      .where(production_releases: {build_id: nil})

    if after
      builds.where("generated_at > ?", after.generated_at).where.not(id: after.id)
    else
      builds
    end
  end

  def next_build_sequence_number
    builds.maximum(:sequence_number).to_i.succ
  end

  def check_release_health
    deployment_runs.each(&:check_release_health)
  end

  def release_metadatum
    release_metadata.where(locale: ReleaseMetadata::DEFAULT_LOCALES).first
  end

  def default_release_metadata
    release_metadata.where(default_locale: true).first
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

  # rubocop:disable Rails/SkipsModelValidations
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
  # rubocop:enable Rails/SkipsModelValidations

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

  def metadata_editable_v2?
    return unless active?
    return false if active_production_release.present? && inflight_production_release.blank?

    inflight_production_release.blank? || inflight_production_release.store_submission.pre_review?
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
    return false if last_commit.blank?
    return false if ongoing_release_step?(step) && train.hotfix_release.present?
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
    return true if train.hotfix_release.present? && train.hotfix_release != release && step.release?

    (next_step == step) && previous_step_run_for(step)&.success? && upcoming_release_step?(step)
  end

  def temporary_unblock_upcoming?
    Flipper.enabled?(:temporary_unblock_upcoming, self)
  end

  def upcoming_release_step?(step)
    step.release? && release.upcoming? && !temporary_unblock_upcoming?
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
    on_track? && finished_steps?
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
    train.vcs_provider&.tag_url(tag_name)
  end

  # recursively attempt to create a release tag until a unique one gets created
  # it *can* get expensive in the worst-case scenario, so ideally invoke this in a bg job
  def create_tag!(input_tag_name = base_tag_name)
    train.create_tag!(input_tag_name, last_commit.commit_hash)
    update!(tag_name: input_tag_name)
    event_stamp!(reason: :tag_created, kind: :notice, data: {tag: tag_name})
  rescue Installations::Error => ex
    raise unless ex.reason == :tag_reference_already_exists
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
    if release.is_v2?
      latest_production_release&.version_bump_required?
    else
      store_release = latest_deployed_store_release
      store_release&.status&.in?(DeploymentRun::READY_STATES) && store_release.step_run.basic_build_version == release_version
    end
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
      .where(scheduled_at: ..step_run.scheduled_at)
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
        app_platform: release_platform.display_attr(:platform),
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

  def block_play_store_submissions!
    update!(play_store_blocked: true)
  end

  def unblock_play_store_submissions!
    update!(play_store_blocked: false)
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

  def set_config
    self.config = release_platform.config
  end
end
