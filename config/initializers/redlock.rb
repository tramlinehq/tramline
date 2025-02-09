require "redis_queued_locks"

Rails.application.config.distributed_lock =
  RedisQueuedLocks::Client.new(REDIS_CONFIGURATION.base).new_pool(REDIS_CONFIGURATION.base[:pool]) do |config|
    config.default_queue_ttl = 15 # seconds
    config.default_lock_ttl = 120_000 # milliseconds
    config.retry_delay = 200 # milliseconds
    config.retry_count = 25
  end
