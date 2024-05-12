class ReleaseKickoffJob < ApplicationJob
  include Loggable

  queue_as :high

  def perform(scheduled_release_id)
    scheduled_release = ScheduledRelease.find_by(id: scheduled_release_id)
    return if scheduled_release.blank?
    return unless scheduled_release.train.active?

    scheduled_release.train.stop_failed_ongoing_release!
    response = Triggers::Release.call(scheduled_release.train, automatic: true)

    if response.success?
      release = response.body
      scheduled_release.update!(is_success: true, release:)
    else
      failure_reason = response.body
      scheduled_release.update!(failure_reason:)
    end
  end
end
