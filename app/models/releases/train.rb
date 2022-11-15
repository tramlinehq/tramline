# == Schema Information
#
# Table name: trains
#
#  id                       :uuid             not null, primary key
#  app_id                   :uuid             not null
#  name                     :string           not null
#  description              :string           not null
#  status                   :string           not null
#  version_seeded_with      :string           not null
#  version_current          :string
#  slug                     :string
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  working_branch           :string
#  branching_strategy       :string
#  release_branch           :string
#  release_backmerge_branch :string
#
class Releases::Train < ApplicationRecord
  has_paper_trail
  using RefinedString
  extend FriendlyId

  EXTERNAL_DEPLOYMENT_CHANNEL = ["None (outside Tramline)", nil]
  BRANCHING_STRATEGIES = {
    almost_trunk: "Almost Trunk",
    release_backmerge: "Release with Backmerge",
    parallel_working: "Parallel Working and Release"
  }.freeze

  belongs_to :app, optional: false
  has_many :integrations, through: :app
  has_many :runs, class_name: "Releases::Train::Run", inverse_of: :train
  has_one :active_run, -> { pending_release }, class_name: "Releases::Train::Run", inverse_of: :train, dependent: :destroy
  has_many :steps, -> { order(:step_number) }, class_name: "Releases::Step", inverse_of: :train, dependent: :destroy
  has_many :train_sign_off_groups, dependent: :destroy
  has_many :sign_off_groups, through: :train_sign_off_groups
  has_many :commit_listeners, class_name: "Releases::CommitListener", inverse_of: :train, dependent: :destroy
  has_many :commits, class_name: "Releases::Commit", inverse_of: :train, dependent: :destroy
  has_many :deployments, through: :steps

  scope :running, -> { includes(:runs).where(runs: { status: Releases::Train::Run.statuses[:on_track] }) }

  enum status: {
    active: "active",
    inactive: "inactive"
  }

  friendly_id :name, use: :slugged
  auto_strip_attributes :name, squish: true

  validates :branching_strategy, :working_branch, presence: true
  validates :release_backmerge_branch, presence: true,
            if: lambda { |record|
              record.branching_strategy == "release_backmerge"
            }
  validates :release_branch, presence: true,
            if: lambda { |record|
              record.branching_strategy == "parallel_working"
            }
  validates :branching_strategy, inclusion: { in: BRANCHING_STRATEGIES.keys.map(&:to_s) }

  validate :semver_compatibility
  validate :ready?, on: :create
  validates :name, format: { with: /\A[a-zA-Z0-9\s_\/-]+\z/, message: "can only contain alphanumerics, underscores, hyphens and forward-slashes." }

  before_create :set_current_version!
  before_create :set_default_status!
  after_create :create_webhook!
  before_destroy :ensure_deletable, prepend: true do
    throw(:abort) if errors.present?
  end

  delegate :ready?, to: :app
  delegate :vcs_provider, to: :integrations
  delegate :ci_cd_provider, to: :integrations
  delegate :notification_provider, to: :integrations
  delegate :unzip_artifact?, to: :ci_cd_provider

  self.ignored_columns = [:signoff_enabled]

  def self.running?
    running.any?
  end

  def set_default_status!
    self.status = Releases::Step.statuses[:active]
  end

  def create_webhook!
    return false if Rails.env.test?
    vcs_provider.create_webhook!(train_id: id)
  rescue Installations::Errors::WebhookLimitReached
    errors.add(:webhooks, "We can't create any more webhooks in your VCS/CI environment!")
    raise ActiveRecord::RecordInvalid, self
  end

  def create_tag!(branch_name)
    return false if Rails.env.test?
    vcs_provider.create_tag!(tag_name, branch_name)
  end

  def create_release!(tag_name)
    return false if Rails.env.test?
    vcs_provider.create_release!(tag_name)
  end

  def create_branch!(from, to)
    return false if Rails.env.test?
    vcs_provider.create_branch!(from, to)
  end

  # FIXME: this is helpful to segregate Slack as a notification channel from deployment channel
  # but eventually, solve that problem through a better abstraction that segregates the two
  def notify!(message:, text_block: {}, channel: nil, provider: nil)
    return unless app.notifications?
    Triggers::Notification(train: self, message:, text_block:, channel:, provider:)
  end

  def display_name
    name.strip.downcase.gsub(/\s+/, "-")
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

  def set_current_version!
    self.version_current = version_seeded_with.semver_bump(:minor)
  end

  def branching_strategy_name
    BRANCHING_STRATEGIES[branching_strategy.to_sym]
  end

  def build_channel_integrations
    app
      .integrations
      .build_channel
      .pluck(:providable_type, :id)
      .push(EXTERNAL_DEPLOYMENT_CHANNEL)
  end

  def final_deployment_channel
    steps.order(:step_number).last.deployments.last&.integration&.providable
  end

  def fully_qualified_working_branch_hack
    [app.config.code_repository_organization_name_hack, ":", working_branch].join
  end

  def fully_qualified_release_branch_hack
    [app.config.code_repository_organization_name_hack, ":", release_branch].join
  end

  def fully_qualified_release_backmerge_branch_hack
    [app.config.code_repository_organization_name_hack, ":", release_backmerge_branch].join
  end

  def pre_release_prs?
    branching_strategy == "parallel_working"
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
end
