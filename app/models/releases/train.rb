# == Schema Information
#
# Table name: trains
#
#  id                       :uuid             not null, primary key
#  branching_strategy       :string
#  description              :string           not null
#  name                     :string           not null
#  platform                 :string
#  release_backmerge_branch :string
#  release_branch           :string
#  slug                     :string
#  status                   :string           not null
#  version_current          :string
#  version_seeded_with      :string           not null
#  working_branch           :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  app_id                   :uuid             not null, indexed
#  train_group_id           :uuid
#  vcs_webhook_id           :string
#
class Releases::Train < ApplicationRecord
  has_paper_trail
  using RefinedString
  extend FriendlyId

  BRANCHING_STRATEGIES = {
    almost_trunk: "Almost Trunk",
    release_backmerge: "Release with Backmerge",
    parallel_working: "Parallel Working and Release"
  }.freeze

  belongs_to :app
  belongs_to :train_group, class_name: "Releases::TrainGroup"
  has_many :integrations, through: :train_group
  has_many :runs, class_name: "Releases::Train::Run", inverse_of: :train, dependent: :destroy
  has_one :active_run, -> { pending_release }, class_name: "Releases::Train::Run", inverse_of: :train, dependent: :destroy
  has_many :steps, -> { order(:step_number) }, class_name: "Releases::Step", inverse_of: :train, dependent: :destroy
  has_many :deployments, through: :steps

  scope :running, -> { includes(:runs).where(runs: {status: Releases::Train::Run.statuses[:on_track]}) }
  scope :only_with_runs, -> { joins(:runs).where.not(runs: {status: "stopped"}).distinct }

  enum status: {
    draft: "draft",
    active: "active",
    inactive: "inactive"
  }
  enum platform: {android: "android", ios: "ios"}

  friendly_id :name, use: :slugged
  auto_strip_attributes :name, squish: true

  validate :semver_compatibility, on: :create
  validate :ready?, on: :create
  validate :valid_step_configuration, on: :activate_context
  validates :name, format: {with: /\A[a-zA-Z0-9\s_\/-]+\z/, message: I18n.t("train_name")}

  before_destroy :ensure_deletable, prepend: true do
    throw(:abort) if errors.present?
  end

  delegate :vcs_provider, :ci_cd_provider, :notification_provider, :store_provider, to: :integrations
  delegate :unzip_artifact?, to: :ci_cd_provider
  delegate :app, to: :train_group
  delegate :ready?, :config, to: :app
  # delegate :branching_strategy, :release_backmerge_branch, :release_branch, :version_current, :version_seeded_with, :working_branch, to: :train_group

  def self.running?
    running.any?
  end

  def has_release_step?
    steps.release.any?
  end

  alias_method :startable?, :has_release_step?

  def release_step
    steps.release.first
  end

  def activate!
    self.status = Releases::Train.statuses[:active]
    save!(context: :activate_context)
  end

  def notify!(message, type, params)
    return unless activated?
    return unless app.send_notifications?
    notification_provider.notify!(config.notification_channel_id, message, type, params)
  end

  def display_name
    name&.parameterize
  end

  def build_channel_integrations
    app.integrations.build_channel
  end

  def final_deployment_channel
    steps.order(:step_number).last.deployments.last&.integration&.providable
  end

  def ordered_steps_until(step_number)
    steps.where("step_number <= ?", step_number).order(:step_number)
  end

  def activated?
    !Rails.env.test? && active?
  end

  def in_creation?
    steps.release.none? && !steps.review.any?
  end

  def demo?
    Flipper.enabled?(:demo_mode, self)
  end

  def valid_steps?
    steps.release.size == 1
  end

  private

  def set_default_platform
    self.platform ||= app.platform
  end

  def ensure_deletable
    errors.add(:trains, "cannot delete a train if there are releases made from it!") if runs.present?
  end

  def semver_compatibility
    VersioningStrategies::Semverish.new(version_seeded_with)
  rescue ArgumentError
    errors.add(:version_seeded_with, "Please choose a valid semver-like format, eg. major.minor.patch or major.minor")
  end

  def valid_step_configuration
    unless valid_steps?
      errors.add(:steps, "there should be one release step")
    end
  end

  def set_constituent_seed_versions
    semverish = version_seeded_with.to_semverish
    self.major_version_seed, self.minor_version_seed, self.patch_version_seed = semverish.major, semverish.minor, semverish.patch
  end
end
