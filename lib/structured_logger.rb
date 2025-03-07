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
end
