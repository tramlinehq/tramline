if ENV["RAILS_PIPELINE_ENV"].eql?("staging")
  Rails.application.config.session_store :redis_store,
    servers: [ENV["SESSION_REDIS_URL"]],
    expire_after: (ENV["SESSION_TIMEOUT_IN_MINUTES"]&.to_i&.minutes || 5.days),
    key: "_tramline_site_session",
    threadsafe: true,
    same_site: :lax,
    secure: true
else
  Rails.application.config.session_store :cookie_store,
    key: "_tramline_site_session",
    secure: true,
    expire_after: (ENV["SESSION_TIMEOUT_IN_MINUTES"]&.to_i&.minutes || 5.days),
    same_site: :lax
end
