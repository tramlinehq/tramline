Rails.application.config.session_store :cookie_store,
  key: "_tramline_site_session",
  secure: false, # All cookies have their secure flag set by the force_ssl option in production
  expires_in: (ENV["SESSION_TIMEOUT_IN_MINUTES"]&.to_i&.minutes || 5.days),
  same_site: :lax
