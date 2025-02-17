class RedisConfiguration
  CONNECT_TIMEOUT = 10

  def base
    @base ||= {
      url: ENV["DEFAULT_REDIS_URL"],
      driver: driver,
      connect_timeout: CONNECT_TIMEOUT
    }
  end

  # sidekiq does its own connection pooling
  def sidekiq
    @sidekiq ||= {
      url: ENV["SIDEKIQ_REDIS_URL"],
      driver: driver,
      connect_timeout: CONNECT_TIMEOUT
    }
  end

  def cache
    @cache ||=
      if ENV["DEFAULT_REDIS_URL"].present?
        [:redis_cache_store,
          {
            url: ENV["DEFAULT_REDIS_URL"],
            driver: driver,
            connect_timeout: CONNECT_TIMEOUT,
            pool: base_pool
          }]
      else
        :memory_store
      end
  end

  def base_pool
    {
      size: Integer(ENV["RAILS_MAX_THREADS"] || 5),
      timeout: CONNECT_TIMEOUT
    }
  end

  private

  # this can eventually be changed to hiredis if required
  def driver = :ruby
end
