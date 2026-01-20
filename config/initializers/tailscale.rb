# frozen_string_literal: true

# Auto-populate TUNNELED_HOST_NAME and WEBHOOK_HOST_NAME from Tailscale Funnel
# The tailscale container writes the URL to tmp/tailscale_url when funnel is ready
if Rails.env.development?
  tailscale_url_file = Rails.root.join("tmp/tailscale_url")

  if tailscale_url_file.exist?
    tunnel_url = tailscale_url_file.read.strip
    if tunnel_url.present? && tunnel_url.include?(".ts.net")
      ENV["TUNNELED_HOST_NAME"] = tunnel_url
      ENV["WEBHOOK_HOST_NAME"] = tunnel_url
      Rails.logger.info "[Tailscale] Using tunnel URL: #{tunnel_url}"
    end
  end
end
