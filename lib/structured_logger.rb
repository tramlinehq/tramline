# Ensure Tagged Logging formatter plays nicely with Ougai.
# See also https://github.com/tilfin/ougai/wiki/Use-as-Rails-logger
module ActiveSupport::TaggedLogging::Formatter
  def call(severity, time, progname, data)
    data = {msg: data.to_s} unless data.is_a?(Hash)
    tags = current_tags
    data[:tags] = tags if tags.present?
    _call(severity, time, progname, data)
  end
end

class StructuredLogger < Ougai::Logger
  include ActiveSupport::LoggerThreadSafeLevel
  include ActiveSupport::LoggerSilence

  # Ruby Logger severity (Integer) -> Sentry structured-logs method.
  # Ougai skips ::Logger#add entirely (info -> _log -> append -> write -> super_add),
  # so Sentry's built-in :logger patch never sees our lines. We forward them here
  # instead, mirroring what lands on stdout (i.e. what Dozzle shows) into Sentry Logs.
  SENTRY_LOG_METHODS = {
    ::Logger::DEBUG => :debug,
    ::Logger::INFO => :info,
    ::Logger::WARN => :warn,
    ::Logger::ERROR => :error,
    ::Logger::FATAL => :fatal,
    ::Logger::UNKNOWN => :fatal
  }.freeze

  def initialize(*args)
    super
    after_initialize if respond_to? :after_initialize
  end

  def create_formatter
    if Rails.env.local?
      Ougai::Formatters::Readable.new
    else
      Ougai::Formatters::Bunyan.new
    end
  end

  # `append` is Ougai's single choke point for emitting a log (and is only reached
  # for messages at/above the configured level, so level filtering already applies).
  # We forward a copy to Sentry Logs, then fall through to normal stdout logging.
  def append(severity, args)
    forward_to_sentry(severity, args)
    super
  end

  private

  # Forwards a log line to Sentry's structured Logs. Best-effort: it must never
  # raise into the logging path, and it no-ops unless Sentry is live (which, per
  # enabled_environments, means production with logs enabled).
  def forward_to_sentry(severity, args)
    return unless defined?(::Sentry) && ::Sentry.initialized?
    return unless ::Sentry.configuration&.enable_logs

    method = SENTRY_LOG_METHODS[severity] || :info
    item = to_item(args)
    message = (item.delete(:msg) || default_message).to_s
    ::Sentry.logger.public_send(method, message, **sentry_attributes(item))
  rescue => e
    # Surface the failure once via the SDK's own diagnostic logger, never to the caller.
    ::Sentry.configuration&.sdk_logger&.warn("failed to forward log to Sentry: #{e.class}") if defined?(::Sentry)
    nil
  end

  # Sentry log attributes must be symbol-keyed scalars; coerce anything else to a
  # string so structured payloads (tags array, exception hash, nested data) still ship.
  def sentry_attributes(item)
    item.each_with_object({}) do |(key, value), attrs|
      next if value.nil?
      attrs[key.to_sym] =
        case value
        when String, Integer, Float, true, false then value
        else value.to_s
        end
    end
  end
end
