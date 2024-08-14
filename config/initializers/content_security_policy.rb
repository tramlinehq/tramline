# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy
# For further information see the following documentation
# https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy

def connect_src_uris
  ENV["CSP_CONNECT_SRC_URIS"]&.split(",") || []
end

def csp_reporting_uri
  report_uri = Addressable::URI.parse(ENV["SENTRY_SECURITY_HEADER_ENDPOINT"])
  report_uri&.query_values = report_uri&.query_values&.merge(sentry_environment: ENV["SENTRY_CURRENT_ENV"])
  report_uri
end

def report_only
  return true if ENV["CSP_REPORT_ONLY"]&.downcase == "true"
  return false if ENV["CSP_REPORT_ONLY"]&.downcase == "false"
  true
end

Rails.application.config.content_security_policy do |policy|
  policy.default_src(:self, :https)
  policy.base_uri(:self, :https)
  policy.font_src(:self, :https, :data)
  policy.img_src(:self, :https, :data)
  policy.object_src(:none)
  policy.script_src(:self, :https, :unsafe_eval)
  policy.style_src(:self, :https, :unsafe_inline)
  policy.worker_src(:self, :https, :blob)
  policy.connect_src(:self, *connect_src_uris)
  policy.child_src(:self, *connect_src_uris)
  policy.report_uri(csp_reporting_uri.to_s) if csp_reporting_uri.present?
end

Rails.application.config.content_security_policy_nonce_generator = ->(request) { Base64.strict_encode64(request.session.id.to_s) }
Rails.application.config.content_security_policy_nonce_directives = %w[script-src]
Rails.application.config.content_security_policy_report_only = report_only
