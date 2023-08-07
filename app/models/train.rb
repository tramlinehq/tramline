# == Schema Information
#
# Table name: trains
#
#  id                       :uuid             not null, primary key
#  branching_strategy       :string           not null
#  description              :string
#  kickoff_at               :datetime
#  name                     :string           not null
#  release_backmerge_branch :string
#  release_branch           :string
#  repeat_duration          :interval
#  slug                     :string
#  status                   :string           not null
#  version_current          :string
#  version_seeded_with      :string
#  working_branch           :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  app_id                   :uuid             not null, indexed
#  vcs_webhook_id           :string
#
class Train < ApplicationRecord
  has_paper_trail
  using RefinedString
  extend FriendlyId

  BRANCHING_STRATEGIES = {
    almost_trunk: "Almost Trunk",
    release_backmerge: "Release with Backmerge",
    parallel_working: "Parallel Working and Release"
  }.freeze

  belongs_to :app
  has_many :releases, -> { sequential }, inverse_of: :train, dependent: :destroy
  has_one :active_run, -> { pending_release }, class_name: "Release", inverse_of: :train, dependent: :destroy
  has_many :release_platforms, dependent: :destroy
  has_many :integrations, through: :app
  has_many :steps, through: :release_platforms
  has_many :deployments, through: :steps
  has_many :scheduled_releases, dependent: :destroy

  scope :sequential, -> { order("trains.created_at ASC") }
  scope :running, -> { includes(:releases).where(releases: {status: Release.statuses[:on_track]}) }
  scope :only_with_runs, -> { joins(:releases).where.not(releases: {status: "stopped"}).distinct }

  delegate :ready?, :config, to: :app
  delegate :vcs_provider, :ci_cd_provider, :notification_provider, to: :integrations

  enum status: {
    draft: "draft",
    active: "active",
    inactive: "inactive"
  }

  friendly_id :name, use: :slugged
  auto_strip_attributes :name, squish: true
  attr_accessor :major_version_seed, :minor_version_seed, :patch_version_seed

  validates :branching_strategy, :working_branch, presence: true
  validates :branching_strategy, inclusion: {in: BRANCHING_STRATEGIES.keys.map(&:to_s)}
  validates :release_backmerge_branch, presence: true, if: -> { branching_strategy == "release_backmerge" }
  validates :release_branch, presence: true, if: -> { branching_strategy == "parallel_working" }
  validate :semver_compatibility, on: :create
  validate :ready?, on: :create
  validate :valid_schedule, on: :create
  validate :valid_train_configuration, on: :activate_context
  validates :name, format: {with: /\A[a-zA-Z0-9\s_\/-]+\z/, message: I18n.t("train_name")}

  # TODO: Remove this accessor, once the migration is complete
  attr_accessor :in_data_migration_mode

  after_initialize :set_constituent_seed_versions, if: :persisted?, unless: :in_data_migration_mode
  before_validation :set_version_seeded_with, if: :new_record?, unless: :in_data_migration_mode
  before_create :set_current_version, unless: :in_data_migration_mode
  before_create :set_default_status, unless: :in_data_migration_mode
  after_create :create_release_platforms, unless: :in_data_migration_mode

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

  def schedule_release!
    scheduled_releases.create!(scheduled_at: next_run_at)
  end

  def automatic?
    kickoff_at.present? && repeat_duration.present?
  end

  def next_run_at
    base_time = last_run_at
    now = Time.current

    return base_time if now < base_time

    time_difference = now - base_time
    passed_durations = (time_difference / repeat_duration.to_i).ceil
    base_time + (repeat_duration.to_i * passed_durations)
  end

  def runnable?
    next_run_at > last_run_at
  end

  def last_run_at
    scheduled_releases.last&.scheduled_at || kickoff_at
  end

  def diff_since_last_release?
    return true if last_finished_release.blank?
    vcs_provider.commit_log(last_finished_release.tag_name, working_branch).any?
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

  def display_name
    name&.parameterize
  end

  def release_branch_name_fmt
    "r/#{display_name}/%Y-%m-%d"
  end

  def activate!
    if valid?(context: :activate_context)
      update(status: Train.statuses[:active])
      schedule_release! if automatic?
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
    automatic? && active? && active_run.blank?
  end

  def manually_startable?
    startable? && active?
  end

  def branching_strategy_name
    BRANCHING_STRATEGIES[branching_strategy.to_sym]
  end

  def build_channel_integrations
    integrations.build_channel
  end

  def next_version(has_major_bump = false)
    bump_term = has_major_bump ? :major : :minor
    version_current.ver_bump(bump_term)
  end

  def next_release_version(has_major_bump = false)
    return next_version(has_major_bump) if has_major_bump || releases.any?
    version_current
  end

  def bump_release!(has_major_bump = false)
    if has_major_bump || releases.any?
      self.version_current = next_version(has_major_bump)
      save!
    end

    version_current
  end

  def bump_fix!
    if releases.any?
      semverish = version_current.to_semverish
      self.version_current = semverish.bump!(:patch).to_s if semverish.proper?
      self.version_current = semverish.bump!(:minor).to_s if semverish.partial?
      save!
    end

    version_current
  end

  def pre_release_prs?
    branching_strategy == "parallel_working"
  end

  def tag_name
    "v#{version_current}"
  end

  def create_release!(branch_name)
    return false unless activated?
    vcs_provider.create_release!(tag_name, branch_name)
  end

  def create_branch!(from, to)
    return false unless activated?
    vcs_provider.create_branch!(from, to)
  end

  def notify!(message, type, params)
    return unless activated?
    return unless app.send_notifications?
    notification_provider.notify!(config.notification_channel_id, message, type, params)
  end

  def notification_params
    app.notification_params.merge(
      {
        train_name: name,
        train_current_version: version_current
      }
    )
  end

  private

  def last_finished_release
    releases.where(status: "finished").order(completed_at: :desc).first
  end

  def set_constituent_seed_versions
    semverish = version_seeded_with.to_semverish
    self.major_version_seed, self.minor_version_seed, self.patch_version_seed = semverish.major, semverish.minor, semverish.patch
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
    self.version_current = version_seeded_with.ver_bump(:minor)
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
      errors.add(:kickoff_at, "scheduled trains allowed only for Almost Trunk branching strategy") if branching_strategy != "almost_trunk"
    end
  end

  def activated?
    !Rails.env.test? && active?
  end
end
