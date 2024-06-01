Sentry.init do |config|
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  config.enabled_environments = %w[production]
  # config.traces_sample_rate = 0.5
  config.traces_sampler = lambda do |sampling_context|
    return 0.0 if ENV["RAILS_PIPELINE_ENV"].eql?("staging")
    transaction_context = sampling_context[:transaction_context]
    op = transaction_context[:op]
    case op
    when /request/ # web requests
      0.2
    when /sidekiq/i # background jobs
      0.05
    else
      0.0
    end
  end
  config.send_default_pii = true
  config.logger = Logger.new($stdout)
  config.logger.level = Logger::WARN
end
