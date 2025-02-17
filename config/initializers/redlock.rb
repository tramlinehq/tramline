require "redis_queued_locks"

Rails.application.config.distributed_lock =
  RedisClient.config(**REDIS_CONFIGURATION.base).new_pool(**REDIS_CONFIGURATION.base_pool).then do |redis_client|
    RedisQueuedLocks::Client.new(redis_client) do |config|
      config.default_queue_ttl = 15 # seconds
      config.default_lock_ttl = 120_000 # milliseconds
      config.retry_delay = 200 # milliseconds
      config.retry_count = 25
    end
  end
