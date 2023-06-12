# == Schema Information
#
# Table name: train_groups
#
#  id                       :uuid             not null, primary key
#  branching_strategy       :string           not null
#  description              :string           not null
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
class Releases::TrainGroup < ApplicationRecord
  has_paper_trail
  using RefinedString
  extend FriendlyId

  BRANCHING_STRATEGIES = {
    almost_trunk: "Almost Trunk",
    release_backmerge: "Release with Backmerge",
    parallel_working: "Parallel Working and Release"
  }.freeze

  belongs_to :app, optional: false
  has_many :runs, class_name: "Releases::TrainGroup::Run", inverse_of: :train_group, dependent: :destroy
  has_one :active_run, -> { pending_release }, class_name: "Releases::TrainGroup::Run", inverse_of: :train_group, dependent: :destroy
  has_many :trains, class_name: "Releases::Train", dependent: :destroy
  has_many :integrations, through: :app
  has_many :commit_listeners, class_name: "Releases::CommitListener", inverse_of: :train_group, dependent: :destroy

  delegate :ready?, :config, to: :app
  delegate :vcs_provider, :ci_cd_provider, :notification_provider, :store_provider, to: :integrations

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

  after_create :create_trains

  before_destroy :ensure_deletable, prepend: true do
    throw(:abort) if errors.present?
  end

  def create_webhook!
    return false if Rails.env.test?
    result = vcs_provider.find_or_create_webhook!(id: vcs_webhook_id, train_id: id)

    self.vcs_webhook_id = result.value![:id]
    save!
  end

  def ios_train
    trains.ios.first
  end

  def android_train
    trains.android.first
  end

  def create_trains
    Rails.logger.info("Creating trains for groups!")
    trains.create!(
      platform: Releases::Train.platforms[:ios],
      branching_strategy:,
      description:,
      name: name + " iOS",
      release_backmerge_branch:,
      release_branch:,
      working_branch:,
      app: app,
      version_seeded_with:,
      version_current:
    )
    trains.create!(
      platform: Releases::Train.platforms[:android],
      branching_strategy:,
      description:,
      name: name + " Android",
      release_backmerge_branch:,
      release_branch:,
      working_branch:,
      app: app,
      version_seeded_with:,
      version_current:
    )
    Rails.logger.info("Created trains for groups!")
  end

  def display_name
    name&.parameterize
  end

  def release_branch_name_fmt
    "r/#{display_name}/%Y-%m-%d"
  end

  def activate!
    self.status = Releases::TrainGroup.statuses[:active]
    save!(context: :activate_context)
  end

  def in_creation?
    trains.any?(&:in_creation?)
  end

  def startable?
    trains.all?(&:startable?)
  end

  def branching_strategy_name
    BRANCHING_STRATEGIES[branching_strategy.to_sym]
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
    self.status ||= Releases::TrainGroup.statuses[:draft]
  end

  def ensure_deletable
    errors.add(:train_groups, "cannot delete a train if there are releases made from it!") if runs.present?
  end

  def valid_train_configuration
    unless trains.all?(&:valid_steps?)
      errors.add(:trains, "there should be one release step")
    end
  end

  def bump_release!(has_major_bump = false)
    bump_term = has_major_bump ? :major : :minor

    if runs.any?
      self.version_current = version_current.ver_bump(bump_term)
      save!
      ios_train.update!(version_current: version_current)
      android_train.update!(version_current: version_current)
    end

    version_current
  end

  def pre_release_prs?
    branching_strategy == "parallel_working"
  end

  def tag_name
    "v#{version_current}"
  end

  def create_tag!(branch_name)
    return false unless activated?
    vcs_provider.create_tag!(tag_name, branch_name)
  end

  def create_branch!(from, to)
    return false unless activated?
    vcs_provider.create_branch!(from, to)
  end

  def activated?
    !Rails.env.test? && active?
  end

  def notify!(message, type, params)
    return unless activated?
    return unless app.send_notifications?
    notification_provider.notify!(config.notification_channel_id, message, type, params)
  end
end
