HEADER_CHECK_PATHS = {
  db: "site-db",
  redis: "site-redis"
}

Easymon::Repository.add(
  HEADER_CHECK_PATHS[:db],
  Easymon::ActiveRecordCheck.new(ActiveRecord::Base),
  :critical
)

Easymon::Repository.add(
  HEADER_CHECK_PATHS[:redis],
  Easymon::RedisCheck.new(
    YAML.load(
      ERB.new(Rails.root.join("config/redis.yml").read).result,
      aliases: true
    )[Rails.env].symbolize_keys
  ),
  :critical
)

Easymon.authorize_with = proc { |request|
  if request.path =~ HEADER_CHECK_PATHS[:db] && request.get? || request.path =~ HEADER_CHECK_PATHS[:redis] && request.get?
    request.headers["X-Monitor-Allowed"] == ENV["X_MONITOR_ALLOWED"]
  end
}
