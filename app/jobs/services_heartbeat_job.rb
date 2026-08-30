class ServicesHeartbeatJob < ApplicationJob
  # Dead-man's-switch for external services: if applelink is reachable, ping the
  # heartbeat URL. If applelink is down (or this doesn't run), the ping never
  # lands and the external monitor alerts. Was the site-services-health-prod
  # Render cron (rake health:services_heartbeat).
  def perform
    return if ENV["EXT_SERVICES_HEARTBEAT_URL"].blank?
    # Bounded timeouts so a stalled endpoint can't pin the worker thread.
    http = HTTP.timeout(connect: 5, read: 10)
    return unless http.get("#{ENV["APPLELINK_URL"]}/ping").status.success?
    http.get(ENV["EXT_SERVICES_HEARTBEAT_URL"])
  end
end
