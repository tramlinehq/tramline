require "jobs_middleware/client/logging_context"
require "jobs_middleware/server/logging_context"

Sidekiq.configure_client do |config|
  config.redis = {url: ENV["SIDEKIQ_REDIS_URL"]}

  config.client_middleware do |chain|
    chain.add JobsMiddleware::Client::LoggingContext
  end
end

strict_args_mode = Rails.env.development? ? :warn : false
Sidekiq.strict_args!(strict_args_mode)

Sidekiq.configure_server do |config|
  config.redis = {url: ENV["SIDEKIQ_REDIS_URL"]}

  config.server_middleware do |chain|
    chain.add JobsMiddleware::Server::LoggingContext
  end

  config.on(:startup) do
    schedule_file = "config/schedule.yml"

    if File.exist?(schedule_file)
      Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file)
    end
  end

  config.error_handlers << ->(ex, _ctx) do
    Sentry.capture_exception(ex)
  end
end
