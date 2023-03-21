Sentry.init do |config|
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  config.enabled_environments = %w[production]
  config.traces_sample_rate = 0.5
  config.send_default_pii = true
  config.logger = Logger.new($stdout)
  config.logger.level = Logger::WARN
end
