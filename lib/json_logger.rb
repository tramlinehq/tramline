class JsonLogger < Ougai::Logger
  include ActiveSupport::LoggerThreadSafeLevel
  include ActiveSupport::LoggerSilence

  def initialize(*args)
    super
    after_initialize if respond_to? :after_initialize
  end

  def create_formatter
    LoggingExtensions.default_log_formatter
  end
end
