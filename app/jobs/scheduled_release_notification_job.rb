class ScheduledReleaseNotificationJob < ApplicationJob
  include Loggable

  queue_as :high

  def perform(scheduled_release_id)
    scheduled_release = ScheduledRelease.find_by(id: scheduled_release_id)
    return if scheduled_release.blank?
    return unless scheduled_release.train.active?

    scheduled_release.train.notify!("A release is scheduled", :release_scheduled, scheduled_release.notification_params)
  end
end
