class Releases::Train < ApplicationRecord
  extend FriendlyId

  belongs_to :app
  has_many :runs, class_name: "Releases::Train::Run", inverse_of: :train
  has_many :steps, class_name: "Releases::Step", inverse_of: :train

  enum status: {
    active: "active",
    inactive: "inactive"
  }

  friendly_id :name, use: :slugged

  attribute :repeat_duration, :interval

  GRACE_PERIOD_FOR_RUNNING = 30.seconds

  def activate!
    update!(status: Releases::Train.statuses[:active])
  end

  def runnable?
    now = Time.now
    run_count = runs.size || 1

    (kickoff_at + (repeat_duration * run_count))
      .between?(now + GRACE_PERIOD_FOR_RUNNING, now - GRACE_PERIOD_FOR_RUNNING)
  end
end
