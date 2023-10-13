# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy
# For further information see the following documentation
# https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy

Rails.application.config.content_security_policy do |policy|
  policy.default_src(:self, :https)
  policy.base_uri(:self, :https)
  policy.font_src(:self, :https, :data)
  policy.img_src(:self, :https, :data)
  policy.object_src(:none)
  policy.script_src(:self, :https, :unsafe_inline, :unsafe_eval)
  policy.style_src(:self, :https, :unsafe_inline)
  policy.connect_src(:self, :https, "http://localhost:3035", "ws://localhost:3035") if Rails.env.development?
  policy.connect_src(
    :self,
    "https://via.intercom.io",
    "https://api.intercom.io",
    "https://api.au.intercom.io",
    "https://api.eu.intercom.io",
    "https://api-iam.intercom.io",
    "https://api-iam.eu.intercom.io",
    "https://api-iam.au.intercom.io",
    "https://api-ping.intercom.io",
    "https://nexus-websocket-a.intercom.io",
    "wss://nexus-websocket-a.intercom.io",
    "https://nexus-websocket-b.intercom.io",
    "wss://nexus-websocket-b.intercom.io",
    "https://nexus-europe-websocket.intercom.io",
    "wss://nexus-europe-websocket.intercom.io",
    "https://nexus-australia-websocket.intercom.io",
    "wss://nexus-australia-websocket.intercom.io",
    "https://uploads.intercomcdn.com",
    "https://uploads.intercomcdn.eu",
    "https://uploads.au.intercomcdn.com",
    "https://uploads.intercomusercontent.com"
  )
  report_uri = Addressable::URI.parse(ENV["SENTRY_SECURITY_HEADER_ENDPOINT"])
  report_uri&.query_values = report_uri&.query_values&.merge(sentry_environment: ENV["SENTRY_CURRENT_ENV"])
  policy.report_uri(report_uri.to_s)
end

Rails.application.config.content_security_policy_nonce_generator = ->(request) { Base64.strict_encode64(request.session.id.to_s) }
Rails.application.config.content_security_policy_nonce_directives = %w[script-src]
Rails.application.config.content_security_policy_report_only = -> {
  return true if ENV["CSP_REPORT_ONLY"]&.downcase == "true"
  return false if ENV["CSP_REPORT_ONLY"]&.downcase == "false"
  true
}.call
