module Loggable
  def elog(e, level:)
    Rails.logger.public_send(level, e)
    sentry_level = (level == :warn) ? :warning : level
    if e.is_a? Exception
      Sentry.capture_exception(e, level: sentry_level)
    elsif e.is_a? String
      Sentry.capture_message(e, level: sentry_level)
    end
    nil
  end

  def self.included(base)
    base.extend(self)
  end
end
