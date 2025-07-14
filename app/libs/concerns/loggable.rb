module Loggable
  def elog(e, level:)
    log(level, e)
    sentry_level = (level == :warn) ? :warning : level
    Sentry.capture_exception(e, level: sentry_level)
    nil
  end

  def log(level, msg_or_e)
    case level
    when :warn
      Rails.logger.warn(msg_or_e)
      Sentry.logger.warn(msg_or_e)
    when :error
      Rails.logger.error(msg_or_e)
      if msg_or_e.is_a?(Exception)
        Sentry.logger.error(msg_or_e.message)
      else
        Sentry.logger.error(msg_or_e)
      end
    when :debug
      Rails.logger.debug { msg_or_e }
      Sentry.logger.debug(msg_or_e)
    when :info
      Rails.logger.info(msg_or_e)
      Sentry.logger.info(msg_or_e)
    else
      raise ArgumentError, "Unknown log level: #{level}"
    end

    nil
  end

  def self.included(base)
    base.extend(self)
  end
end
