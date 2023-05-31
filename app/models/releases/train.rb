# == Schema Information
#
# Table name: trains
#
#  id                       :uuid             not null, primary key
#  branching_strategy       :string
#  description              :string           not null
#  name                     :string           not null
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

  belongs_to :app, optional: false
  has_many :integrations, through: :app
  has_many :runs, class_name: "Releases::Train::Run", inverse_of: :train, dependent: :destroy
  has_one :active_run, -> { pending_release }, class_name: "Releases::Train::Run", inverse_of: :train, dependent: :destroy
  has_many :steps, -> { order(:step_number) }, class_name: "Releases::Step", inverse_of: :train, dependent: :destroy
  has_many :commit_listeners, class_name: "Releases::CommitListener", inverse_of: :train, dependent: :destroy
  has_many :commits, class_name: "Releases::Commit", inverse_of: :train, dependent: :destroy
  has_many :deployments, through: :steps

  scope :running, -> { includes(:runs).where(runs: {status: Releases::Train::Run.statuses[:on_track]}) }
  scope :only_with_runs, -> { joins(:runs).where.not(runs: {status: "stopped"}).distinct }

  enum status: {
    draft: "draft",
    active: "active",
    inactive: "inactive"
  }

  friendly_id :name, use: :slugged
  auto_strip_attributes :name, squish: true
  attr_accessor :major_version_seed, :minor_version_seed, :patch_version_seed

  validates :branching_strategy, :working_branch, presence: true
  validates :release_backmerge_branch, presence: true,
    if: lambda { |record|
      record.branching_strategy == "release_backmerge"
    }
  validates :release_branch, presence: true,
    if: lambda { |record|
      record.branching_strategy == "parallel_working"
    }
  validates :branching_strategy, inclusion: {in: BRANCHING_STRATEGIES.keys.map(&:to_s)}

  validate :semver_compatibility
  validate :ready?, on: :create
  validate :valid_step_configuration, on: :activate_context
  validates :name, format: {with: /\A[a-zA-Z0-9\s_\/-]+\z/, message: I18n.t("train_name")}

  before_create :set_current_version
  before_create :set_default_status
  before_destroy :ensure_deletable, prepend: true do
    throw(:abort) if errors.present?
  end

  delegate :vcs_provider, :ci_cd_provider, :notification_provider, :store_provider, to: :integrations
  delegate :unzip_artifact?, to: :ci_cd_provider
  delegate :ready?, :config, to: :app

  def create_webhook!
    return false if Rails.env.test?
    result = vcs_provider.find_or_create_webhook!(id: vcs_webhook_id, train_id: id)

    self.vcs_webhook_id = result.value![:id]
    save!
  end

  def self.running?
    running.any?
  end

  def set_default_status
    self.status ||= Releases::Train.statuses[:draft]
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

  def create_tag!(branch_name)
    return false unless activated?
    vcs_provider.create_tag!(tag_name, branch_name)
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

  def display_name
    name&.parameterize
  end

  def release_branch_name_fmt
    "r/#{display_name}/%Y-%m-%d"
  end

  def tag_name
    "v#{version_current}"
  end

  def bump_version!(element = :minor)
    if runs.any?
      self.version_current = version_current.semver_bump(element)
      save!
    end

    version_current
  end

  def set_current_version
    self.version_current = version_seeded_with.semver_bump(:minor)
  end

  def branching_strategy_name
    BRANCHING_STRATEGIES[branching_strategy.to_sym]
  end

  def build_channel_integrations
    app.integrations.build_channel
  end

  def final_deployment_channel
    steps.order(:step_number).last.deployments.last&.integration&.providable
  end

  def pre_release_prs?
    branching_strategy == "parallel_working"
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

  private

  def ensure_deletable
    errors.add(:trains, "cannot delete a train if there are releases made from it!") if runs.present?
  end

  def semver_compatibility
    Semantic::Version.new(version_seeded_with)
  rescue ArgumentError
    errors.add(:version_seeded_with, "Please choose a valid semver format, eg. major.minor.patch")
  end

  def valid_step_configuration
    unless steps.release.size == 1
      errors.add(:steps, "there should be one release step")
    end
  end
end
