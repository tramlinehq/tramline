module Loggable
  def elog(e, level: :info)
    Rails.logger.error(e)
    Sentry.capture_exception(e, level:)
    nil
  end

  def self.included(base)
    base.extend(self)
  end
end
