# == Schema Information
#
# Table name: trains
#
#  id                       :uuid             not null, primary key
#  branching_strategy       :string           not null
#  description              :string
#  name                     :string           not null
#  release_backmerge_branch :string
#  release_branch           :string
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

  validate :semver_compatibility, on: :create
  validate :ready?, on: :create
  validate :valid_train_configuration, on: :activate_context
  validates :name, format: {with: /\A[a-zA-Z0-9\s_\/-]+\z/, message: I18n.t("train_name")}

  after_initialize :set_constituent_seed_versions, if: :persisted?
  before_validation :set_version_seeded_with, if: :new_record?
  before_create :set_current_version
  before_create :set_default_status
  after_create :create_release_platforms

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
    release_platforms.all?(&:valid_steps?)
    self.status = Train.statuses[:active]
    save!(context: :activate_context)
  end

  def in_creation?
    release_platforms.any?(&:in_creation?)
  end

  def startable?
    release_platforms.all?(&:startable?)
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

  delegate :create_tag!, to: :vcs_provider

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
      errors.add(:release_platforms, "there should be one release step")
    end
  end

  def activated?
    !Rails.env.test? && active?
  end
end
