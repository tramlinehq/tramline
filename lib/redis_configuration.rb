class RedisConfiguration
  CONNECT_TIMEOUT = 5

  def base
    @base ||= {
      url: ENV["DEFAULT_REDIS_URL"],
      driver: driver,
      connect_timeout: CONNECT_TIMEOUT,
      pool: {
        size: Integer(ENV["RAILS_MAX_THREADS"] || 5),
        timeout: CONNECT_TIMEOUT,
      },
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
           pool: {
             size: Integer(ENV["RAILS_MAX_THREADS"] || 5),
             timeout: CONNECT_TIMEOUT,
           },
         }
        ]
      else
        :memory_store
      end
  end

  private

  def driver
    ENV["REDIS_DRIVER"] == "ruby" ? :ruby : :hiredis
  end
end
