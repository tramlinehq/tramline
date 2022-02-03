module SidekiqConfig
  DEFAULT_SIDEKIQ_REDIS_POOL = 12

  def self.connection_pool
    puts "hi2u"
    ConnectionPool.new(size: DEFAULT_SIDEKIQ_REDIS_POOL) do
      if ENV["SIDEKIQ_REDIS_URL"].present?
        puts "hi2u"
        Redis.new(url: ENV["SIDEKIQ_REDIS_URL"])
      else
        puts "hi2u"
        Redis.new
      end
    end
  end
end

Sidekiq.configure_client do |config|
  config.redis = SidekiqConfig.connection_pool
end

Sidekiq.configure_server do |config|
  config.on(:shutdown) { Statsd.instance.close }
  config.redis = SidekiqConfig.connection_pool
end