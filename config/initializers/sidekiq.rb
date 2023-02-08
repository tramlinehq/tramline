Sidekiq.configure_client do |config|
  config.redis = {url: ENV["SIDEKIQ_REDIS_URL"]}
end

Sidekiq.configure_server do |config|
  config.redis = {url: ENV["SIDEKIQ_REDIS_URL"]}

  config.on(:startup) do
    schedule_file = "config/schedule.yml"

    if File.exist?(schedule_file)
      Sidekiq::Cron::Job.load_from_hash YAML.load_file(schedule_file)
    end
  end
end
