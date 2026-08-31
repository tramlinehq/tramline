Sentry.init do |config|
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  config.enabled_environments = %w[production]
  config.traces_sample_rate = 0.5
  # config.traces_sampler = lambda do |sampling_context|
  #   return 0.0 if ENV["RAILS_PIPELINE_ENV"].eql?("staging")
  #   transaction_context = sampling_context[:transaction_context]
  #   op = transaction_context[:op]
  #   case op
  #   when /request/ # web requests
  #     0.2
  #   when /sidekiq/i # background jobs
  #     0.05
  #   else
  #     0.0
  #   end
  # end
  config.send_default_pii = true
  config.sdk_logger = Logger.new($stdout)          # SDK-internal diagnostic logger (renamed from config.logger in 5.28); NOT the Logs feature
  config.sdk_logger.level = Logger::WARN

  # Sentry structured Logs (ships only in production, per enabled_environments above).
  # See https://docs.sentry.io/platforms/ruby/guides/rails/logs/
  config.enable_logs = true

  # Enabling logs would otherwise auto-attach Rails structured-logging subscribers,
  # whose active_record subscriber emits one Sentry log PER SQL query ("Database
  # query: X Load") — a firehose that isn't on stdout/Dozzle and buries everything
  # else. We forward our actual stdout log lines instead, via StructuredLogger's
  # Sentry hook (lib/structured_logger.rb), so turn the subscribers off.
  config.rails.structured_logging.enabled = false
end
