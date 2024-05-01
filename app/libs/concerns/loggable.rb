module Loggable
  def elog(e)
    Rails.logger.error(e)
    Sentry.capture_exception(e)
    nil
  end
end
