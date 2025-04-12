#!/bin/bash

set -euo pipefail

echo "Starting setup on GCP VM..."

if ! command -v docker >/dev/null 2>&1; then
  echo "📦 Installing Docker..."
  sudo apt-get update && sudo apt-get install -y docker.io
else
  echo "Docker already installed"
fi

if ! command -v docker-compose >/dev/null 2>&1; then
  echo "Installing Docker Compose..."
  sudo apt-get install -y docker-compose
else
  echo "Docker Compose already installed"
fi

sudo usermod -aG docker "$USER"
newgrp docker <<EOF
echo "Reloaded shell group to apply docker permissions"
EOF

echo "Cloning tramline repo..."
git clone https://github.com/tramlinehq/tramline.git
cd tramline

# NOTE: remove this line once we're ready to merge the PR
git checkout sam/docker-compose-move-staging

echo "🔐 Creating .env.staging..."
cat <<EOF > .env.staging
RAILS_ENV=production
RACK_ENV=production
RAILS_MASTER_KEY=your-master-key-here

DATABASE_URL=postgres://postgres:password@db:5432/tramline_gcp_staging

REDIS_URL=redis://redis:6379
DEFAULT_REDIS_URL=redis://redis:6379
SESSION_REDIS_URL=redis://redis:6379
SIDEKIQ_REDIS_URL=redis://redis:6379

APP_REDIRECT_MAPPING=your-redirect-config
BILLING_URL=https://billing.example.com
INTERCOM_APP_ID=your-intercom-app-id

ANONYMIZE_SOURCE_DB_HOST=localhost
ANONYMIZE_SOURCE_DB_PORT=5432
ANONYMIZE_SOURCE_DB_NAME=anonymize
ANONYMIZE_SOURCE_DB_USERNAME=user
ANONYMIZE_SOURCE_DB_PASSWORD=pass
EOF

echo "Pulling & starting Docker services..."
docker compose pull
docker compose up -d

echo " Running db:setup..."
docker compose exec web bin/rails db:setup
