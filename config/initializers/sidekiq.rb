module SidekiqConfig
  DEFAULT_SIDEKIQ_REDIS_POOL = 12

  def self.connection_pool
    ConnectionPool.new(size: DEFAULT_SIDEKIQ_REDIS_POOL) do
      if ENV["SIDEKIQ_REDIS_URL"].present?
        Redis.new(url: ENV.fetch("SIDEKIQ_REDIS_URL", nil))
      else
        Redis.new
      end
    end
  end
end

Sidekiq.configure_client do |config|
  config.redis = SidekiqConfig.connection_pool
end

Sidekiq.configure_server do |config|
  config.redis = SidekiqConfig.connection_pool
end
