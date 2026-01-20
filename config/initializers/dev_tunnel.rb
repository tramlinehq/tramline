# frozen_string_literal: true

# Read tunnel URL from file written by tailscale container
# The tailscale container writes the funnel URL to tmp/tunnel_url
if Rails.env.development?
  tunnel_url_file = Rails.root.join("tmp/tunnel_url")

  if tunnel_url_file.exist?
    tunnel_url = tunnel_url_file.read.strip
    if tunnel_url.present?
      ENV["TUNNELED_HOST_NAME"] = tunnel_url
      ENV["WEBHOOK_HOST_NAME"] = tunnel_url
      Rails.logger.info "[DevTunnel] Using tunnel URL: #{tunnel_url}"
    end
  end
end
