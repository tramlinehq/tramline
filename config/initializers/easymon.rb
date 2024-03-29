Easymon::Repository.add(
  "site-db",
  Easymon::ActiveRecordCheck.new(ActiveRecord::Base),
  :critical
)

Easymon::Repository.add(
  "site-redis",
  Easymon::RedisCheck.new(
    YAML.load(
      ERB.new(Rails.root.join("config/redis.yml").read).result,
      aliases: true
    )[Rails.env].symbolize_keys
  ),
  :critical
)

Easymon.authorize_with = proc { |request| request.headers["X-Monitor-Allowed"] == ENV["X_MONITOR_ALLOWED"] }
