Easymon::Repository.add(
  "site-db",
  Easymon::ActiveRecordCheck.new(ActiveRecord::Base),
  :critical
)

Easymon::Repository.add(
  "site-redis-cache",
  Easymon::RedisCheck.new(REDIS_CONFIGURATION.base),
  :critical
)

Easymon::Repository.add(
  "site-redis-sidekiq",
  Easymon::RedisCheck.new(REDIS_CONFIGURATION.sidekiq),
  :critical
)

Easymon.authorize_with = proc { |request| request.headers["X-Monitor-Allowed"] == ENV["X_MONITOR_ALLOWED"] }
