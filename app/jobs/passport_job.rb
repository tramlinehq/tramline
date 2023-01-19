class PassportJob < ApplicationJob
  queue_as :high

  def perform(stampable_id, stampable_type, reason:, kind:, message:, metadata:, event_timestamp:)
    stampable =
      begin
        stampable_type.constantize.find(stampable_id)
      rescue NameError, ActiveRecord::RecordNotFound => e
        Sentry.capture_exception(e)
      end

    Passport.stamp!(stampable:, reason:, kind:, message:, metadata:, event_timestamp:)
  end
end
