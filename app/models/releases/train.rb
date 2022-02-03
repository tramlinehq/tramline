class Releases::Train < ApplicationRecord
  extend FriendlyId

  belongs_to :app
  has_many :integrations, through: :app
  has_many :runs, class_name: "Releases::Train::Run", inverse_of: :train
  has_many :steps, class_name: "Releases::Step", inverse_of: :train

  enum status: {
    active: "active",
    inactive: "inactive"
  }

  friendly_id :name, use: :slugged

  attribute :repeat_duration, :interval

  after_initialize :set_default_status
  after_create :create_webhook!

  delegate :integrations_are_ready?, to: :app

  def set_default_status
    self.status = Releases::Step.statuses[:active]
  end

  def create_webhook!
    Automatons::Webhook.dispatch!(train: self)
  end

  GRACE_PERIOD_FOR_RUNNING = 30.seconds

  def runnable?
    Time.use_zone(app.timezone) do
      now = Time.now

      next_run_at
        .in_time_zone(app.timezone)
        .between?(now - GRACE_PERIOD_FOR_RUNNING, now + GRACE_PERIOD_FOR_RUNNING)
    end
  end

  def next_run_at
    kickoff_at + (repeat_duration * (runs.finished.size || 1))
  end

  def current_run
    runs.on_track.last
  end
end
