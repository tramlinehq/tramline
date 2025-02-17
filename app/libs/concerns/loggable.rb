module Loggable
  def elog(e, level: :error)
    Rails.logger.public_send(level, e)
    sentry_level = (level == :warn) ? :warning : level
    Sentry.capture_exception(e, level: sentry_level)
    nil
  end

  def self.included(base)
    base.extend(self)
  end
end
