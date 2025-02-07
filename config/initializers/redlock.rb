require "redis_queued_locks"

Rails.application.config.distributed_lock =
  RedisQueuedLocks::Client.new(RedisClient.config(url: ENV["DEFAULT_REDIS_URL"]).new_pool) do |config|
    config.default_queue_ttl = 15 # seconds
    config.default_lock_ttl = 120_000 # milliseconds
    config.retry_delay = 200 # milliseconds
    config.retry_count = 3
  end
