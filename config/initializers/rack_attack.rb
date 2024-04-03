# config/initializers/rack_attack.rb

Rack::Attack.throttled_responder = lambda do |_request|
  [429, {}, ["Too many requests. Please wait and try again later.\n"]]
end

Rack::Attack.throttle("forgot_password_requests_by_email", limit: (Rails.env.development? ? 100 : 3), period: 1.hour) do |req|
  if req.path == "/users/password" && req.post? && req.params["user"].present?
    req.params["user"]["email"].to_s.downcase # Use the email address as a discriminator
  end
end
