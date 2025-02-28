Rails.application.config.distributed_lock_client =
  Redlock::Client.new([RedisClient.new(**REDIS_CONFIGURATION.base)], {
    retry_count: 3,
    retry_delay: 200, # milliseconds
    redis_timeout: RedisConfiguration::CONNECT_TIMEOUT
  })
