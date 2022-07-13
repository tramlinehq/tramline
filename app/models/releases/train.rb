class Releases::Train < ApplicationRecord
  has_paper_trail
  using RefinedString
  extend FriendlyId

  BRANCHING_STRATEGIES = {
    almost_trunk: "Almost Trunk",
    release_backmerge: "Release Backmerge",
    parallel_working: "Parallel working"
  }.freeze

  belongs_to :app, optional: false
  has_many :integrations, through: :app
  has_many :runs, class_name: "Releases::Train::Run", inverse_of: :train, dependent: :destroy
  has_one :active_run, -> { where(status: "on_track") }, class_name: "Releases::Train::Run", inverse_of: :train, dependent: :destroy
  has_many :steps, -> { order(:step_number) }, class_name: "Releases::Step", inverse_of: :train, dependent: :destroy
  has_many :train_sign_off_groups, dependent: :destroy
  has_many :sign_off_groups, through: :train_sign_off_groups
  has_many :commit_listeners, class_name: "Releases::CommitListener", inverse_of: :train, dependent: :destroy
  has_many :commits, class_name: "Releases::Commit", inverse_of: :train, dependent: :destroy

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

  enum status: {
    active: "active",
    inactive: "inactive"
  }

  friendly_id :name, use: :slugged

  validate :semver_compatibility
  validate :ready?, on: :create
  validates :version_suffix, uniqueness: {scope: :app}

  before_create :set_current_version!
  before_create :set_default_status!
  after_create :create_webhook!

  delegate :ready?, to: :app
  delegate :vcs_provider, to: :integrations
  delegate :ci_cd_provider, to: :integrations
  delegate :notification_provider, to: :integrations

  self.ignored_columns = [:signoff_enabled]

  def set_default_status!
    self.status = Releases::Step.statuses[:active]
  end

  def create_webhook!
    return false if Rails.env.test?

    Automatons::Webhook.dispatch!(train: self)
  end

  GRACE_PERIOD_FOR_RUNNING = 30.seconds
  MINIMUM_TRAIN_KICKOFF_DELAY = 30.minutes

  def display_name
    name.downcase.tr(" ", "-")
  end

  def tag_name
    "v#{version_current}"
  end

  def bump_version!(element = :minor)
    self.version_current = version_current.semver_bump(element)
    save!
    version_current
  end

  def set_current_version!
    self.version_current = version_seeded_with
  end

  def branching_strategy_name
    BRANCHING_STRATEGIES[branching_strategy.to_sym]
  end

  private

  def semver_compatibility
    Semantic::Version.new(version_seeded_with)
  rescue ArgumentError
    errors.add(:version_seeded_with, "Please choose a valid semver format, eg. major.minor.patch")
  end
end
