class Releases::Train < ApplicationRecord
  has_paper_trail
  using RefinedString
  extend FriendlyId

  EXTERNAL_DEPLOYMENT_CHANNEL = {"None (outside Tramline)" => "external"}
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
  has_many :train_sign_off_groups, dependent: :destroy
  has_many :sign_off_groups, through: :train_sign_off_groups
  has_many :commit_listeners, class_name: "Releases::CommitListener", inverse_of: :train, dependent: :destroy
  has_many :commits, class_name: "Releases::Commit", inverse_of: :train, dependent: :destroy

  scope :running, -> { includes(:runs).where(runs: {status: Releases::Train::Run.statuses[:on_track]}) }

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
  validates :branching_strategy, inclusion: {in: BRANCHING_STRATEGIES.keys.map(&:to_s)}

  validate :semver_compatibility
  validate :ready?, on: :create
  validates :version_suffix, uniqueness: {scope: :app}
  validates :name, format: {with: /\A[a-zA-Z0-9\s_\/-]+\z/, message: "can only contain alphanumerics, underscores, hyphens and forward-slashes."}

  before_create :set_current_version!
  before_create :set_default_status!
  after_create :create_webhook!

  delegate :ready?, to: :app
  delegate :vcs_provider, to: :integrations
  delegate :ci_cd_provider, to: :integrations
  delegate :notification_provider, to: :integrations

  self.ignored_columns = [:signoff_enabled]

  def self.running?
    running.any?
  end

  def set_default_status!
    self.status = Releases::Step.statuses[:active]
  end

  def create_webhook!
    return false if Rails.env.test?
    vcs_provider.create_webhook!(train_id: id) && ci_cd_provider.create_webhook!(train_id: id)
  end

  def create_tag!(branch_name)
    return false if Rails.env.test?
    vcs_provider.create_tag!(tag_name, branch_name)
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
    app.integrations.build_channel.pluck(:providable_type).index_by do |integration|
      integration.gsub("Integration", "").titleize
    end.merge(EXTERNAL_DEPLOYMENT_CHANNEL)
  end

  def final_deployment_channel
    steps.order(:step_number).last.build_artifact_integration.gsub("Integration", "").titleize
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

  private

  def semver_compatibility
    Semantic::Version.new(version_seeded_with)
  rescue ArgumentError
    errors.add(:version_seeded_with, "Please choose a valid semver format, eg. major.minor.patch")
  end
end
