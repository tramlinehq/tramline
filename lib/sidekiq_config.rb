module SidekiqConfig
  DEFAULT_SIDEKIQ_REDIS_POOL = 12

  def self.connection_pool
    ConnectionPool.new(size: DEFAULT_SIDEKIQ_REDIS_POOL) do
      if ENV["SIDEKIQ_REDIS_URL"].present?
        Redis.new(url: ENV["SIDEKIQ_REDIS_URL"])
      else
        Redis.new
      end
    end
  end
end
