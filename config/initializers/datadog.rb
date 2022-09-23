require "site_extensions"
require "ddtrace"
require "datadog/statsd"

# Allow running via an ENV var (for development usage, for example), otherwise exclude some envs by default
DATADOG_ENABLED = ENV["DATADOG_ENABLED"] || !(Rails.env.development? || Rails.env.test?)

Datadog.configure do |c|
  c.tracing.enabled = DATADOG_ENABLED
  c.version = Site.git_ref
  c.profiling.enabled = false
end

require "statsd"
require "metrics"
