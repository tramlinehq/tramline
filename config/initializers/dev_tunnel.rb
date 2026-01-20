# frozen_string_literal: true

# Fetch tunnel URL from running tailscale container and set env vars
if Rails.env.development?
  tunnel_url = `bin/get-tunnel-url 2>/dev/null`.strip

  if tunnel_url.present? && !tunnel_url.start_with?("ERROR")
    ENV["TUNNELED_HOST_NAME"] = tunnel_url
    ENV["WEBHOOK_HOST_NAME"] = tunnel_url
    Rails.logger.info "[DevTunnel] Using tunnel URL: #{tunnel_url}"
  end
end
