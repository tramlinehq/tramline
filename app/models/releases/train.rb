class Releases::Train < ApplicationRecord
  has_paper_trail
  using RefinedString
  extend FriendlyId

  belongs_to :app, required: true
  has_many :integrations, through: :app
  has_many :runs, class_name: "Releases::Train::Run", inverse_of: :train
  has_many :steps, class_name: "Releases::Step", inverse_of: :train

  enum status: {
    active: "active",
    inactive: "inactive"
  }

  friendly_id :name, use: :slugged

  attribute :repeat_duration, :interval

  validate :semver_compatibility
  validate :kickoff_in_the_future, on: :create
  validate :ready?, on: :create
  validates_uniqueness_of :version_suffix, scope: :app

  before_create :set_current_version!
  before_create :set_default_status!
  after_create :create_webhook!

  delegate :ready?, to: :app
  delegate :vcs_provider, to: :integrations
  delegate :ci_cd_provider, to: :integrations
  delegate :notification_provider, to: :integrations

  def set_default_status!
    self.status = Releases::Step.statuses[:active]
  end

  def create_webhook!
    Automatons::Webhook.dispatch!(train: self)
  end

  GRACE_PERIOD_FOR_RUNNING = 30.seconds
  MINIMUM_TRAIN_KICKOFF_DELAY = 30.minutes

  def runnable?
    Time.use_zone(app.timezone) do
      now = Time.current

      next_run_at
        .in_time_zone(app.timezone)
        .between?(now - GRACE_PERIOD_FOR_RUNNING, now + GRACE_PERIOD_FOR_RUNNING)
    end
  end

  def next_run_at
    kickoff_at + (repeat_duration * ([runs.finished.size, runs.on_track.size].max || 1))
  end

  def current_run
    runs.on_track.last
  end

  def display_name
    name.downcase.tr(" ", "-")
  end

  def tag_name
    "v#{version_current}"
  end

  def bump_version!
    self.version_current = version_current.semver_bump(:minor)
    save!
    version_current
  end

  def set_current_version!
    self.version_current = version_seeded_with
  end

  private

  def semver_compatibility
    Semantic::Version.new(version_seeded_with)
  rescue ArgumentError
    errors.add(:version_seeded_with, "Please choose a valid semver format, eg. major.minor.patch")
  end

  def kickoff_in_the_future
    Time.use_zone(app.timezone) do
      unless kickoff_at > Time.current + MINIMUM_TRAIN_KICKOFF_DELAY
        errors.add(:kickoff_at, "Please kickoff the train at least #{MINIMUM_TRAIN_KICKOFF_DELAY.inspect} from now")
      end
    end
  end
end
