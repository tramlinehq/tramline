# == Schema Information
#
# Table name: scheduled_releases
#
#  id             :uuid             not null, primary key
#  failure_reason :string
#  is_success     :boolean          default(FALSE)
#  scheduled_at   :datetime         not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  train_id       :uuid             not null, indexed
#
class ScheduledRelease < ApplicationRecord
  has_paper_trail

  self.implicit_order_column = :scheduled_at

  belongs_to :train
  belongs_to :release, optional: true
  delegate :app, to: :train

  scope :pending, -> { where("scheduled_at > ?", Time.current) }

  after_create_commit :schedule_kickoff!

  NOTIFICATION_WINDOW = 3.hours

  def schedule_kickoff!
    ReleaseKickoffJob.set(wait_until: scheduled_at).perform_later(id)
    ScheduledReleaseNotificationJob.set(wait_until: scheduled_at - NOTIFICATION_WINDOW).perform_later(id)
  end

  def notification_params
    train.notification_params.merge(
      {
        release_scheduled_at: scheduled_at.in_time_zone(app.timezone).strftime("%I:%M%p (%Z)")
      }
    )
  end

  def pending?
    scheduled_at > Time.current
  end
end
