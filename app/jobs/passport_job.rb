class PassportJob < ApplicationJob
  include Loggable
  queue_as :high

  def perform(stampable_id, stampable_type, reason:, kind:, message:, metadata:, event_timestamp:, automatic:, author_id:, author_metadata:)
    stampable =
      begin
        stampable_type.constantize.find(stampable_id)
      rescue NameError, ActiveRecord::RecordNotFound => e
        elog(e)
      end

    Passport.stamp!(stampable:, reason:, kind:, message:, metadata:, event_timestamp:, automatic:, author_id:, author_metadata:)
  end
end
