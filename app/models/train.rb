# == Schema Information
#
# Table name: trains
#
#  id                                             :uuid             not null, primary key
#  approvals_enabled                              :boolean          default(FALSE), not null
#  auto_apply_patch_changes                       :boolean          default(TRUE)
#  backmerge_strategy                             :string           default("on_finalize"), not null
#  branching_strategy                             :string           not null
#  build_queue_enabled                            :boolean          default(FALSE)
#  build_queue_size                               :integer
#  build_queue_wait_time                          :interval
#  compact_build_notes                            :boolean          default(FALSE)
#  continuous_backmerge_branch_prefix             :string
#  copy_approvals                                 :boolean          default(FALSE)
#  description                                    :string
#  enable_changelog_linking_in_notifications      :boolean          default(FALSE)
#  freeze_version                                 :boolean          default(FALSE)
#  kickoff_at                                     :datetime
#  name                                           :string           not null
#  notification_channel                           :jsonb
#  notifications_release_specific_channel_enabled :boolean          default(FALSE)
#  patch_version_bump_only                        :boolean          default(FALSE), not null
#  release_backmerge_branch                       :string
#  release_branch                                 :string
#  release_branch_pattern                         :string
#  repeat_duration                                :interval
#  slug                                           :string
#  status                                         :string           not null
#  stop_automatic_releases_on_failure             :boolean          default(FALSE), not null
#  tag_end_of_release                             :boolean          default(TRUE)
#  tag_end_of_release_prefix                      :string
#  tag_end_of_release_suffix                      :string
#  tag_end_of_release_vcs_release                 :boolean          default(FALSE)
#  tag_store_releases                             :boolean          default(FALSE)
#  tag_store_releases_vcs_release                 :boolean          default(FALSE)
#  tag_store_releases_with_platform_names         :boolean          default(FALSE)
#  version_bump_branch_prefix                     :string
#  version_bump_enabled                           :boolean          default(FALSE)
#  version_bump_file_paths                        :string           default([]), is an Array
#  version_bump_strategy                          :string
#  version_current                                :string
#  version_seeded_with                            :string
#  versioning_strategy                            :string           default("semver")
#  webhooks_enabled                               :boolean          default(FALSE), not null
#  working_branch                                 :string
#  created_at                                     :datetime         not null
#  updated_at                                     :datetime         not null
#  app_id                                         :uuid             not null, indexed
#  vcs_webhook_id                                 :string
#
class Train < ApplicationRecord
  has_paper_trail
  using RefinedArray
  using RefinedString
  extend FriendlyId
  include Rails.application.routes.url_helpers
  include Versionable
  include Loggable
  include TokenInterpolator

  self.ignored_columns += ["manual_release"]

  BRANCHING_STRATEGIES = {
    almost_trunk: "Almost Trunk",
    release_backmerge: "Release with Backmerge",
    parallel_working: "Parallel Working and Release"
  }.freeze
  ALLOWED_VERSION_BUMP_FILE_TYPES = {
    gradle: ".gradle",
    kotlin_gradle: ".kts",
    plist: ".plist",
    pbxproj: ".pbxproj",
    yaml: ".yaml"
  }.freeze
  VERSION_BUMP_STRATEGIES = {
    current_version_before_release_branch: "Current Version Before Release Branch Cuts",
    next_version_after_release_branch: "Next Version After Release Branch Cuts"
  }.freeze

  belongs_to :app
  has_many :releases, -> { sequential }, inverse_of: :train, dependent: :destroy
  has_many :active_runs, -> { pending_release.includes(:all_commits) }, class_name: "Release", inverse_of: :train, dependent: :destroy
  has_many :release_platforms, -> { sequential }, dependent: :destroy, inverse_of: :train
  has_many :release_platform_runs, -> { sequential }, through: :releases
  has_many :integrations, through: :app
  has_many :scheduled_releases, dependent: :destroy
  has_many :notification_settings, inverse_of: :train, dependent: :destroy
  has_one :release_index, dependent: :destroy
  has_one :webhook_integration, class_name: "SvixIntegration", dependent: :destroy

  scope :sequential, -> { reorder("trains.created_at ASC") }
  scope :running, -> { includes(:releases).where(releases: {status: Release.statuses[:on_track]}) }
  scope :only_with_runs, -> { joins(:releases).where.not(releases: {status: "stopped"}).distinct }

  delegate :ready?, :config, :organization, to: :app
  delegate :vcs_provider, :ci_cd_provider, :notification_provider, :monitoring_provider, to: :integrations

  enum :status, {draft: "draft", active: "active", inactive: "inactive"}
  enum :backmerge_strategy, {continuous: "continuous", on_finalize: "on_finalize"}
  enum :versioning_strategy, VersioningStrategies::Semverish::STRATEGIES.keys.zip_map_self.transform_values(&:to_s)
  enum :version_bump_strategy, VERSION_BUMP_STRATEGIES.keys.zip_map_self.transform_values(&:to_s)

  friendly_id :name, use: :slugged
  normalizes :name, with: ->(name) { name.squish }
  normalizes :release_branch_pattern, with: ->(name) { name.squish }
  attr_accessor :major_version_seed, :minor_version_seed, :patch_version_seed
  attr_accessor :build_queue_wait_time_unit, :build_queue_wait_time_value
  attr_accessor :repeat_duration_unit, :repeat_duration_value, :release_schedule_enabled
  attr_accessor :continuous_backmerge_enabled, :notifications_enabled

  validates :branching_strategy, :working_branch, presence: true
  validates :branching_strategy, inclusion: {in: BRANCHING_STRATEGIES.keys.map(&:to_s)}
  validates :versioning_strategy, presence: true, inclusion: {in: Train.versioning_strategies.values}
  validates :release_backmerge_branch, presence: true, if: -> { branching_strategy == "release_backmerge" }
  validates :release_branch, presence: true, if: -> { branching_strategy == "parallel_working" }
  validate :version_compatibility, on: :create
  validate :ready?, on: :create
  validate :valid_schedule, if: -> { kickoff_at_changed? || repeat_duration_changed? }
  validate :build_queue_config
  validate :backmerge_config
  validate :working_branch_presence, on: :create
  validate :ci_cd_workflows_presence, on: :create
  validates :name, format: {with: /\A[a-zA-Z0-9\s_\/-]+\z/, message: :invalid}
  validate :version_config_constraints
  validate :version_bump_config
  validates :version_bump_strategy, inclusion: {in: VERSION_BUMP_STRATEGIES.keys.map(&:to_s)}, if: -> { version_bump_enabled? }
  validate :validate_token_fields, if: :validate_tokens?

  after_initialize :set_branching_strategy, if: :new_record?
  after_initialize :set_constituent_seed_versions, if: :persisted?
  after_initialize :set_release_schedule, if: :persisted?
  after_initialize :set_build_queue_config, if: :persisted?
  after_initialize :set_backmerge_config, if: :persisted?
  after_initialize :set_notifications_config, if: :persisted?
  before_validation :set_version_seeded_with, if: :new_record?
  before_validation :cleanse_tagging_configs
  before_create :fetch_ci_cd_workflows
  before_create :set_current_version
  before_create :set_default_status
  after_create :create_release_platforms
  after_create :create_default_notification_settings
  after_create :create_release_index
  after_create_commit :create_webhook_integration
  after_update_commit :update_webhook_integration
  before_update :disable_copy_approvals, unless: :approvals_enabled?
  before_update :create_default_notification_settings, if: -> do
    notification_channel_changed? || notifications_release_specific_channel_enabled_changed?
  end
  after_update :schedule_release!, if: -> { kickoff_at.present? && kickoff_at_previously_was.blank? }

  def disable_copy_approvals
    self.copy_approvals = false
  end

  before_destroy :ensure_deletable, prepend: true do
    throw(:abort) if errors.present?
  end

  def self.running?
    running.any?
  end

  def self.ios_review_steps?
    first&.release_platforms&.ios&.first&.steps&.review&.any?
  end

  def self.ios_release_steps?
    first&.release_platforms&.ios&.first&.steps&.release&.any?
  end

  def self.android_review_steps?
    first&.release_platforms&.android&.first&.steps&.review&.any?
  end

  def self.android_release_steps?
    first&.release_platforms&.android&.first&.steps&.release&.any?
  end

  def one_percent_beta_release?
    Flipper.enabled?(:one_percent_beta_release, self)
  end

  def temporarily_allow_workflow_errors?
    Flipper.enabled?(:temporarily_allow_workflow_errors, self)
  end

  def workflows(bust_cache: false)
    @workflows ||= ci_cd_provider&.workflows(working_branch, bust_cache:)
  end

  def version_ahead?(release)
    version_current.to_semverish >= release.release_version.to_semverish
  end

  def ongoing_release
    active_runs.where(release_type: Release.release_types[:release]).order(:scheduled_at).first
  end

  def upcoming_release
    active_runs.where(release_type: Release.release_types[:release]).order(:scheduled_at).second
  end

  def hotfix_release
    active_runs.where(release_type: Release.release_types[:hotfix]).first
  end

  def schedule_release!
    scheduled_releases.create!(scheduled_at: next_run_at) if automatic?
  end

  def hotfix_from
    releases.finished.reorder(completed_at: :desc).first
  end

  def previously_finished_release
    releases.release.finished.reorder(completed_at: :desc).first
  end

  def automatic?
    kickoff_at.present? && repeat_duration.present?
  end

  def next_run_at
    return unless automatic?

    base_time = last_run_at
    now = Time.current

    return base_time if now < base_time

    time_difference = now - base_time
    elapsed_durations = (time_difference / repeat_duration.to_i).ceil
    base_time + (repeat_duration.to_i * elapsed_durations)
  end

  def runnable?
    next_run_at > last_run_at
  end

  def last_run_at
    scheduled_releases.last&.scheduled_at || kickoff_at
  end

  def diff_since_last_release?
    return vcs_provider.diff_between?(ongoing_release.first_commit.commit_hash, working_branch, from_type: :commit) if ongoing_release
    return true if last_finished_release.blank?

    if last_finished_release.tag_name.present?
      last_release_ref, ref_type = last_finished_release.tag_name, :tag
    else
      last_release_ref, ref_type = last_finished_release.last_commit.commit_hash, :commit
    end
    vcs_provider.diff_between?(last_release_ref, working_branch, from_type: ref_type)
  end

  def diff_for_release?
    return false unless parallel_working_branch?
    vcs_provider.diff_between?(release_branch, working_branch, from_type: :branch)
  end

  def create_webhook!
    return false if Rails.env.test?
    result = vcs_provider.find_or_create_webhook!(id: vcs_webhook_id, train_id: id)

    self.vcs_webhook_id = result.value![:id]
    save!
  end

  def ios_train
    release_platforms.ios&.first
  end

  def android_train
    release_platforms.android&.first
  end

  def create_release_platforms
    platforms = app.cross_platform? ? ReleasePlatform.platforms.values : [app.platform]
    platforms.each { |platform| release_platforms.create!(app:, platform:, name: "#{name} #{platform}") }
  rescue ActiveRecord::RecordNotSaved
    errors.add(:base, "There was an error setting up your release. Please try again.")
    raise ActiveRecord::RecordInvalid, self
  end

  # rubocop:disable Rails/SkipsModelValidations
  def create_default_notification_settings
    vals = NotificationSetting.kinds.keys.map { |kind|
      {
        train_id: id,
        kind:,
        active: true,
        core_enabled: true,
        notification_channels: notification_channel.present? ? [notification_channel] : nil
      }
    }

    NotificationSetting.transaction do
      NotificationSetting.upsert_all(vals, unique_by: [:train_id, :kind])
      notification_settings
        .release_specific_channel_allowed
        .update_all(release_specific_enabled: notifications_release_specific_channel_enabled?)
    end
  end

  # rubocop:enable Rails/SkipsModelValidations

  def display_name
    name&.parameterize
  end

  def release_branch_name_fmt(hotfix: false, substitution_tokens: {})
    pattern = release_branch_pattern.presence || "r/~trainName~/~releaseStartDate~"
    pattern = "hotfix/~trainName~/~releaseStartDate~" if hotfix
    interpolate_tokens(pattern, substitution_tokens)
  end

  # TokenInterpolator#token_fields override
  def token_fields
    {
      release_branch_pattern: {
        value: release_branch_pattern,
        allowed_tokens: %w[trainName releaseVersion releaseStartDate]
      }
    }
  end

  def activate!
    if valid?(context: :activate_context)
      update(status: Train.statuses[:active])
      schedule_release!
      true
    end
  end

  def deactivate!
    update(status: Train.statuses[:inactive]) && cancel_scheduled_releases!
  end

  def cancel_scheduled_releases!
    scheduled_releases.pending&.delete_all
  end

  def activatable?
    automatic? && !active?
  end

  def deactivatable?
    automatic? && active? && active_runs.none?
  end

  def upcoming_release_startable?
    !inactive? &&
      ongoing_release.present? &&
      ongoing_release.production_release_started? &&
      upcoming_release.blank?
  end

  def continuous_backmerge?
    backmerge_strategy == Train.backmerge_strategies[:continuous]
  end

  def branching_strategy_name
    BRANCHING_STRATEGIES[branching_strategy.to_sym]
  end

  def active_release_for?(branch_name)
    active_runs.exists?(branch_name: branch_name)
  end

  def open_active_prs_for?(branch_name)
    open_active_prs_for(branch_name).exists?
  end

  def open_active_prs_for(branch_name)
    PullRequest.open.where(release_id: active_runs.ids, head_ref: branch_name)
  end

  def parallel_working_branch?
    branching_strategy == "parallel_working"
  end

  def almost_trunk?
    branching_strategy == "almost_trunk"
  end

  def backmerge_disabled?
    !almost_trunk?
  end

  def create_vcs_release!(branch_name, tag_name, previous_tag_name, release_diff = nil)
    return false unless active?
    vcs_provider.create_release!(tag_name, branch_name, previous_tag_name, release_diff)
  end

  delegate :create_tag!, to: :vcs_provider

  def create_branch!(from, to, source_type: :branch)
    return false unless active?
    vcs_provider.create_branch!(from, to, source_type:)
  end

  def notify!(message, type, params, file_id = nil, file_title = nil)
    return unless active?
    return unless send_notifications?
    notification_settings.where(kind: type).sole.notify!(message, params, file_id, file_title)
  end

  def notify_with_snippet!(message, type, params, snippet_content, snippet_title)
    return unless active?
    return unless send_notifications?
    notification_settings.where(kind: type).sole.notify_with_snippet!(message, params, snippet_content, snippet_title)
  end

  def notify_with_changelog!(message, type, params)
    return unless active?
    return unless send_notifications?
    notification_settings.where(kind: type).sole.notify_with_changelog!(message, params)
  end

  def upload_file_for_notifications!(file, file_name)
    return unless active?
    return unless send_notifications?
    notification_provider.upload_file!(file, file_name)
  end

  def notification_params
    app.notification_params.merge(
      {
        train_name: name,
        train_current_version: version_current,
        train_next_version: next_version,
        train_url: train_link,
        working_branch: working_branch,
        enable_changelog_linking: enable_changelog_linking_in_notifications
      }
    )
  end

  def webhooks_available?
    webhooks_enabled? && webhook_integration&.available?
  end

  def send_notifications?
    # Release-specific notifications and general notifications are not exclusive.
    # Some notifications are not supported (do not make sense) in release-specific mode.
    # So, this does not check for the release-specific flag.
    app.notifications_set_up? && notification_channel.present?
  end

  def schedule_editable?
    draft? || !automatic? || !persisted?
  end

  def hotfixable?
    return false unless app.ready?
    return false unless has_production_deployment?
    return false if hotfix_release.present?
    return false if hotfix_from.blank?
    return true if ongoing_release.blank?

    !ongoing_release.production_release_active?
  end

  def devops_report
    Queries::DevopsReport.new(self)
  end

  def has_production_deployment?
    release_platforms.any? { |rp| rp.platform_config.production_release? }
  end

  def has_restricted_public_channels?
    return false if app.ios?
    release_platforms.any?(&:has_restricted_public_channels?)
  end

  def stop_failed_ongoing_release!
    return unless automatic?
    return unless stop_automatic_releases_on_failure?
    return if ongoing_release.blank?
    return unless ongoing_release.failure_anywhere?

    ongoing_release.stop!
  end

  # call workflows to memoize and cache the result
  def fetch_ci_cd_workflows = workflows

  def last_finished_release
    releases.where(status: "finished").reorder(completed_at: :desc).first
  end

  def previous_releases
    releases
      .includes([:release_platform_runs, hotfixed_from: [:release_platform_runs]])
      .completed
      .where.not(id: last_finished_release)
      .order(completed_at: :desc, scheduled_at: :desc)
  end

  private

  def train_link
    return if Rails.env.test?

    if Rails.env.development?
      app_train_url(app, self, host: ENV["HOST_NAME"], protocol: "https", port: ENV["PORT_NUM"])
    else
      app_train_url(app, self, host: ENV["HOST_NAME"], protocol: "https")
    end
  end

  def set_constituent_seed_versions
    semverish = version_seeded_with.to_semverish
    self.major_version_seed, self.minor_version_seed, self.patch_version_seed = semverish.major, semverish.minor, semverish.patch
  end

  def set_release_schedule
    self.release_schedule_enabled = automatic?
    return if repeat_duration.blank?
    parts = repeat_duration.parts
    self.repeat_duration_unit = parts.keys.first.to_s
    self.repeat_duration_value = parts.values.first
  end

  def set_build_queue_config
    return if build_queue_wait_time.blank?
    parts = build_queue_wait_time.parts
    self.build_queue_wait_time_unit = parts.keys.first.to_s
    self.build_queue_wait_time_value = parts.values.first
  end

  def set_backmerge_config
    self.continuous_backmerge_enabled = continuous_backmerge?
  end

  def set_notifications_config
    self.notifications_enabled = send_notifications?
  end

  def version_compatibility
    semverish = VersioningStrategies::Semverish.new(version_seeded_with)

    unless semverish.valid?(strategy: versioning_strategy)
      errors.add(:version_seeded_with, :"improper_#{versioning_strategy}")
    end
  end

  def set_version_seeded_with
    self.version_seeded_with =
      VersioningStrategies::Semverish.build(major_version_seed, minor_version_seed, patch_version_seed)
  rescue ArgumentError
    nil
  end

  def cleanse_tagging_configs
    # we're currently not using tag_end_of_release_vcs_release
    # so for now, when end-of-release tagging is on, we assume that we must cut the VCS release
    if tag_end_of_release?
      self.tag_end_of_release_vcs_release = true
    end

    unless tag_end_of_release?
      self.tag_end_of_release_vcs_release = false
      self.tag_end_of_release_suffix = nil
      self.tag_end_of_release_prefix = nil
    end

    unless tag_store_releases?
      self.tag_store_releases_vcs_release = false
      self.tag_store_releases_with_platform_names = false
    end

    unless app.cross_platform?
      self.tag_store_releases_with_platform_names = false
    end
  end

  def set_branching_strategy
    self.branching_strategy ||= "almost_trunk"
  end

  def set_current_version
    self.version_current = version_seeded_with
  end

  def set_default_status
    self.status ||= Train.statuses[:draft]
  end

  def ensure_deletable
    errors.add(:trains, "cannot delete a train if there are releases made from it!") if releases.present?
  end

  def valid_schedule
    if kickoff_at.present? || repeat_duration.present?
      errors.add(:repeat_duration, "invalid schedule, provide both kickoff and period for repeat") unless kickoff_at.present? && repeat_duration.present?
      errors.add(:kickoff_at, "the schedule kickoff should be in the future") if kickoff_at && kickoff_at <= Time.current
      errors.add(:repeat_duration, "the repeat duration should be more than 1 day") if repeat_duration && repeat_duration < 1.day
    end
  end

  def backmerge_config
    errors.add(:backmerge_strategy, :continuous_not_allowed) if branching_strategy != "almost_trunk" && continuous_backmerge?
  end

  def working_branch_presence
    errors.add(:working_branch, :not_available) unless vcs_provider.branch_exists?(working_branch)
  end

  def ci_cd_workflows_presence
    errors.add(:base, :ci_cd_workflows_not_available) if workflows.blank?
  end

  def build_queue_config
    if build_queue_enabled?
      errors.add(:build_queue_size, :config_required) unless build_queue_size.present? && build_queue_wait_time.present?
      errors.add(:build_queue_size, :invalid_size) if build_queue_size && build_queue_size < 1
      errors.add(:build_queue_wait_time, :invalid_duration) if build_queue_wait_time && build_queue_wait_time > 360.hours
    else
      errors.add(:build_queue_size, :config_not_allowed) if build_queue_size.present?
      errors.add(:build_queue_wait_time, :config_not_allowed) if build_queue_wait_time.present?
    end
  end

  def version_config_constraints
    if freeze_version && patch_version_bump_only
      errors.add(:base, "both freeze_version and patch_version_bump_only cannot be true at the same time")
    end
  end

  def version_bump_config
    if version_bump_enabled?
      if version_bump_strategy.blank?
        errors.add(:version_bump_strategy, :blank)
        return
      end

      if version_bump_file_paths.blank?
        errors.add(:version_bump_file_paths, :blank)
        return
      end

      if version_bump_file_paths.any?(&:blank?)
        errors.add(:version_bump_file_paths, :blank_file)
        return
      end

      # files must have an extension
      if version_bump_file_paths.any? { |p| File.extname(p.to_s).blank? }
        errors.add(:version_bump_file_paths, :invalid_file_extension)
        return
      end

      # files must have a valid extension
      valid_extensions = ALLOWED_VERSION_BUMP_FILE_TYPES.values
      unless version_bump_file_paths.all? { |p| valid_extensions.include?(File.extname(p.to_s)) }
        errors.add(:version_bump_file_paths, :invalid_file_type, valid_extensions: valid_extensions.join(", "))
      end
    end
  end

  def create_webhook_integration
    return unless webhooks_enabled?
    UpdateOutgoingWebhookIntegrationJob.perform_async(id, true)
  end

  def update_webhook_integration
    return unless saved_change_to_webhooks_enabled?
    UpdateOutgoingWebhookIntegrationJob.perform_async(id, webhooks_enabled?)
  end
end
