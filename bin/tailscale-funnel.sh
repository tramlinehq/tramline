#!/bin/sh
# Tailscale Funnel startup script for Docker
# This script connects to Tailscale and sets up a Funnel to expose the web service

set -e

# Support both TS_AUTHKEY (from compose env) and TAILSCALE_AUTHKEY (from env_file)
AUTH_KEY="${TS_AUTHKEY:-$TAILSCALE_AUTHKEY}"

if [ -z "$AUTH_KEY" ]; then
  echo 'TAILSCALE_AUTHKEY not set - tailscale disabled'
  rm -f /rails/tmp/tunnel_url
  touch /tmp/tailscale_ready
  exec sleep infinity
fi

SOCKS_PORT=$((WEB_PORT + 5000))

# Start tailscaled in userspace networking mode
tailscaled --tun=userspace-networking --socks5-server=localhost:$SOCKS_PORT &

# Wait for tailscaled to be ready and authenticate
until tailscale status 2>/dev/null; do
  echo 'Waiting for tailscaled to start...'
  tailscale up --authkey="$AUTH_KEY" --hostname="tramline-$WORKTREE_NAME" || true
  sleep 2
done

echo 'Tailscale connected!'

# Set up Funnel to expose the web service
tailscale funnel --bg --https=443 --set-path=/ "https+insecure://127.0.0.1:$WEB_PORT"

echo 'Waiting for Funnel URL to become available...'
RETRIES=0
MAX_RETRIES=30
FUNNEL_URL=''

while [ -z "$FUNNEL_URL" ] && [ $RETRIES -lt $MAX_RETRIES ]; do
  # Extract the hostname from the Web section key (e.g., "tramline-main.tail524f2.ts.net:443")
  HOSTNAME=$(tailscale funnel status --json 2>/dev/null | grep -o '"[^"]*\.ts\.net:443"' | head -1 | tr -d '"' | sed 's/:443$//')
  if [ -n "$HOSTNAME" ]; then
    FUNNEL_URL="https://$HOSTNAME"
  else
    RETRIES=$((RETRIES + 1))
    echo "Funnel URL not ready yet (attempt $RETRIES/$MAX_RETRIES)..."
    sleep 2
  fi
done

if [ -z "$FUNNEL_URL" ]; then
  echo "ERROR: Failed to get Funnel URL after $MAX_RETRIES attempts"
  exit 1
fi

echo "$FUNNEL_URL" > /rails/tmp/tunnel_url
echo "Tailscale Funnel URL is $FUNNEL_URL"
touch /tmp/tailscale_ready

exec sleep infinity
