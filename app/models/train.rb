# == Schema Information
#
# Table name: trains
#
#  id                       :uuid             not null, primary key
#  backmerge_strategy       :string           default("on_finalize"), not null
#  branching_strategy       :string           not null
#  build_queue_enabled      :boolean          default(FALSE)
#  build_queue_size         :integer
#  build_queue_wait_time    :interval
#  compact_build_notes      :boolean          default(FALSE)
#  description              :string
#  kickoff_at               :datetime
#  manual_release           :boolean          default(FALSE)
#  name                     :string           not null
#  notification_channel     :jsonb
#  release_backmerge_branch :string
#  release_branch           :string
#  repeat_duration          :interval
#  slug                     :string
#  status                   :string           not null
#  tag_all_store_releases   :boolean          default(FALSE)
#  tag_platform_releases    :boolean          default(FALSE)
#  tag_releases             :boolean          default(TRUE)
#  tag_suffix               :string
#  version_current          :string
#  version_seeded_with      :string
#  versioning_strategy      :string           default("semver")
#  working_branch           :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  app_id                   :uuid             not null, indexed
#  vcs_webhook_id           :string
#
class Train < ApplicationRecord
  has_paper_trail
  using RefinedArray
  using RefinedString
  extend FriendlyId
  include Rails.application.routes.url_helpers
  include Notifiable
  include Versionable
  include Loggable

  BRANCHING_STRATEGIES = {
    almost_trunk: "Almost Trunk",
    release_backmerge: "Release with Backmerge",
    parallel_working: "Parallel Working and Release"
  }.freeze

  belongs_to :app
  has_many :releases, -> { sequential }, inverse_of: :train, dependent: :destroy
  has_many :active_runs, -> { pending_release.includes(:all_commits) }, class_name: "Release", inverse_of: :train, dependent: :destroy
  has_many :deployment_runs, through: :releases
  has_many :external_releases, through: :deployment_runs
  has_many :release_platforms, dependent: :destroy
  has_many :integrations, through: :app
  has_many :steps, through: :release_platforms
  has_many :deployments, through: :steps
  has_many :scheduled_releases, dependent: :destroy
  has_many :notification_settings, inverse_of: :train, dependent: :destroy

  scope :sequential, -> { order("trains.created_at ASC") }
  scope :running, -> { includes(:releases).where(releases: {status: Release.statuses[:on_track]}) }
  scope :only_with_runs, -> { joins(:releases).where.not(releases: {status: "stopped"}).distinct }

  delegate :ready?, :config, :organization, to: :app
  delegate :vcs_provider, :ci_cd_provider, :notification_provider, :monitoring_provider, to: :integrations
  delegate :fixed_build_number?, :custom_release_version?, to: :organization

  enum status: {draft: "draft", active: "active", inactive: "inactive"}
  enum backmerge_strategy: {continuous: "continuous", on_finalize: "on_finalize"}
  enum versioning_strategy: VersioningStrategies::Semverish::STRATEGIES.keys.zip_map_self.transform_values(&:to_s)

  friendly_id :name, use: :slugged
  auto_strip_attributes :name, squish: true
  attr_accessor :major_version_seed, :minor_version_seed, :patch_version_seed
  attr_accessor :build_queue_wait_time_unit, :build_queue_wait_time_value
  attr_accessor :repeat_duration_unit, :repeat_duration_value, :release_schedule_enabled
  attr_accessor :continuous_backmerge_enabled, :notifications_enabled

  validates :branching_strategy, :working_branch, presence: true
  validates :branching_strategy, inclusion: {in: BRANCHING_STRATEGIES.keys.map(&:to_s)}
  validates :versioning_strategy, presence: true, inclusion: {in: Train.versioning_strategies.values}
  validates :release_backmerge_branch, presence: true, if: -> { branching_strategy == "release_backmerge" }
  validates :release_branch, presence: true, if: -> { branching_strategy == "parallel_working" }
  validate :semver_compatibility, on: :create
  validate :ready?, on: :create
  validate :valid_schedule, if: -> { kickoff_at_changed? || repeat_duration_changed? }
  validate :build_queue_config
  validate :backmerge_config
  validate :tag_release_config
  validate :valid_train_configuration, on: :activate_context
  validate :working_branch_presence, on: :create
  validates :name, format: {with: /\A[a-zA-Z0-9\s_\/-]+\z/, message: I18n.t("train_name")}

  after_initialize :set_constituent_seed_versions, if: :persisted?
  after_initialize :set_release_schedule, if: :persisted?
  after_initialize :set_build_queue_config, if: :persisted?
  after_initialize :set_backmerge_config, if: :persisted?
  after_initialize :set_notifications_config, if: :persisted?
  before_validation :set_version_seeded_with, if: :new_record?
  before_create :set_current_version
  before_create :set_default_status
  after_create :create_release_platforms
  after_create :create_default_notification_settings
  after_update :schedule_release!, if: -> { kickoff_at.present? && kickoff_at_previously_was.blank? }
  after_update :create_default_notification_settings, if: -> { notification_channel.present? && notification_channel_previously_was.blank? }

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

  def automatic?
    kickoff_at.present? && repeat_duration.present?
  end

  def tag_platform_at_release_end?
    return false unless app.cross_platform?
    tag_platform_releases? && !tag_all_store_releases?
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
    return vcs_provider.diff_between?(ongoing_release.first_commit.commit_hash, working_branch) if ongoing_release
    return true if last_finished_release.blank?
    vcs_provider.diff_between?(last_finished_release.tag_name || last_finished_release.last_commit.commit_hash, working_branch)
  end

  def diff_for_release?
    return false unless parallel_working_branch?
    vcs_provider.diff_between?(release_branch, working_branch)
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
    platforms.each do |platform|
      release_platforms.create!(
        platform: platform,
        name: "#{name} #{platform}",
        app: app
      )
    end
  end

  def create_default_notification_settings
    return if notification_channel.blank?
    vals = NotificationSetting.kinds.map do |_, kind|
      {
        train_id: id,
        kind:,
        active: true,
        notification_channels: [notification_channel]
      }
    end
    NotificationSetting.upsert_all(vals, unique_by: [:train_id, :kind])
  end

  def display_name
    name&.parameterize
  end

  def release_branch_name_fmt(hotfix: false)
    return "hotfix/#{display_name}/%Y-%m-%d" if hotfix
    "r/#{display_name}/%Y-%m-%d"
  end

  def replicate
    ActiveRecord::Base.transaction do
      new_train = dup
      new_train.name = "#{name} - clone"
      current_version = version_current.to_semverish
      new_train.patch_version_seed = current_version.patch
      new_train.minor_version_seed = current_version.minor
      new_train.major_version_seed = current_version.major
      new_train.kickoff_at = next_run_at
      new_train.status = Train.statuses[:draft]
      new_train.vcs_webhook_id = nil
      new_train.save!
      new_train.reload
      new_train.release_platforms.each do |rp|
        steps = release_platforms.where(platform: rp.platform).sole.steps
        steps.each { |step| step.replicate(rp) }
      end
      notification_settings.presence&.replicate(new_train)
      true
    end
  rescue ActiveRecord::RecordInvalid => e
    elog(e)
    false
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

  def in_creation?
    release_platforms.any?(&:in_creation?)
  end

  def startable?
    release_platforms.all?(&:startable?)
  end

  def activatable?
    automatic? && startable? && !active?
  end

  def deactivatable?
    automatic? && active? && active_runs.none?
  end

  def manually_startable?
    startable? && !inactive?
  end

  def upcoming_release_startable?
    manually_startable? &&
      ongoing_release.present? &&
      release_platforms.any?(&:has_production_deployment?) &&
      release_platforms.all?(&:has_review_steps?)
  end

  def continuous_backmerge?
    backmerge_strategy == Train.backmerge_strategies[:continuous]
  end

  def branching_strategy_name
    BRANCHING_STRATEGIES[branching_strategy.to_sym]
  end

  def build_channel_integrations
    integrations.build_channel
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

  def create_release!(branch_name, tag_name)
    return false unless active?
    vcs_provider.create_release!(tag_name, branch_name)
  end

  delegate :create_tag!, to: :vcs_provider

  def create_branch!(from, to, source_type: :branch)
    return false unless active?
    vcs_provider.create_branch!(from, to, source_type:)
  end

  def notify!(message, type, params)
    return unless active?
    return unless send_notifications?
    notification_settings.where(kind: type).sole.notify!(message, params)
  end

  def notify_with_snippet!(message, type, params, snippet_content, snippet_title)
    return unless active?
    return unless send_notifications?
    notification_settings.where(kind: type).sole.notify_with_snippet!(message, params, snippet_content, snippet_title)
  end

  def notification_params
    app.notification_params.merge(
      {
        train_name: name,
        train_current_version: version_current,
        train_next_version: next_version,
        train_url: train_link,
        working_branch:
      }
    )
  end

  def send_notifications?
    app.notifications_set_up? && notification_channel.present?
  end

  def schedule_editable?
    draft? || !automatic? || !persisted?
  end

  def hotfixable?
    return false if hotfix_release.present?
    return false if ongoing_release.present? && ongoing_release.release_step_started?
    hotfix_from.present? && release_platforms.any?(&:has_production_deployment?)
  end

  def devops_report?(user)
    user.release_health? && releases.size > 1
  end

  def devops_report
    Charts::DevopsReport.all(self)
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

  def last_finished_release
    releases.where(status: "finished").reorder(completed_at: :desc).first
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

  def semver_compatibility
    VersioningStrategies::Semverish.new(version_seeded_with)
  rescue ArgumentError
    errors.add(:version_seeded_with, "Please choose a valid semver-like format, eg. major.minor.patch or major.minor")
  end

  def set_version_seeded_with
    self.version_seeded_with =
      VersioningStrategies::Semverish.build(major_version_seed, minor_version_seed, patch_version_seed)
  rescue ArgumentError
    nil
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

  def valid_train_configuration
    unless release_platforms.all?(&:valid_steps?)
      errors.add(:train, "there should be one release step for all platforms")
    end
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

  def tag_release_config
    errors.add(:tag_all_store_releases, :not_allowed) if tag_all_store_releases? && !tag_platform_releases?
  end

  def working_branch_presence
    errors.add(:working_branch, :not_available) unless vcs_provider.branch_exists?(working_branch)
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
end
