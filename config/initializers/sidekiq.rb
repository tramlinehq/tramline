require "jobs_middleware/client/logging_context"
require "jobs_middleware/server/logging_context"

Sidekiq.configure_client do |config|
  config.redis = REDIS_CONFIGURATION.sidekiq

  config.client_middleware do |chain|
    chain.add JobsMiddleware::Client::LoggingContext
  end
end

strict_args_mode = Rails.env.development? ? :warn : false
Sidekiq.strict_args!(strict_args_mode)

Sidekiq.configure_server do |config|
  config.redis = REDIS_CONFIGURATION.sidekiq

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
    Sentry.capture_exception(ex, level: :warn)
  end

  config.death_handlers << ->(_job, ex) do
    Sentry.capture_exception(ex, level: :error)
  end

  # from https://gitlab.com/gitlab-org/gitlab/-/tree/master/vendor/gems/sidekiq-reliable-fetch
  # semi-reliable fetch uses regular `brpop` and `lpush` to pick the job and put it to working queue.
  # The main benefit of "Reliable" strategy is that rpoplpush is atomic, eliminating a race condition in which jobs can be lost.
  # However, it comes at a cost because `rpoplpush` can't watch multiple lists at the same time so we need to iterate over the entire queue list
  # which significantly increases pressure on Redis when there are more than a few queues.
  # The "semi-reliable" strategy is much more reliable than the default Sidekiq fetcher, though.
  # Compared to the reliable fetch strategy, it does not increase pressure on Redis significantly.
  #
  # Additionally, the reliable strategy relies on `rpoplpush` which will throw up a lot of redis warnings
  # since that command is going to be deprecated in favor of `LMOVE` in future version (>6).
  config[:semi_reliable_fetch] = true
  Sidekiq::ReliableFetch.setup_reliable_fetch!(config)
end
