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
