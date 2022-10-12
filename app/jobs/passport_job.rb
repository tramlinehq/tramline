class PassportJob < ApplicationJob
  queue_as :high
  sidekiq_options retry: 0

  def perform(stampable_id, stampable_type, reason:, kind:, message:, metadata:)
    stampable =
      begin
        stampable_type.constantize.find(stampable_id)
      rescue NameError, ActiveRecord::RecordNotFound => e
        Sentry.capture_exception(e)
      end

    Passport.stamp!(stampable: stampable, reason: reason, kind: kind, message: message, metadata: metadata)
  end
end
