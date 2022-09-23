require "sidekiq_config"

Sidekiq.configure_client do |config|
  config.redis = SidekiqConfig.connection_pool
end

Sidekiq.configure_server do |config|
  config.redis = SidekiqConfig.connection_pool
end
