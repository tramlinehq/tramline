# Hetzner Bare-Metal Setup

Server: Hetzner CPX41 (8 vCPU, 16 GB RAM, AMD EPYC)

## 1. Hetzner Cloud Firewall

Create a firewall in the Hetzner Cloud console and attach it to the server.
This is the primary defense — it sits upstream of the box.

**Inbound rules:**

| Protocol | Port | Source          | Description    |
|----------|------|-----------------|----------------|
| TCP      | 22   | Your IP/32      | SSH            |
| TCP      | 80   | 0.0.0.0/0       | HTTP           |
| TCP      | 443  | 0.0.0.0/0       | HTTPS          |

Block everything else.

## 2. Initial Server Setup

```bash
# SSH in as root
ssh root@<HETZNER_IP>

# Create deploy user
adduser deploy
usermod -aG sudo deploy

# Set up SSH key auth for deploy user
mkdir -p /home/deploy/.ssh
cp ~/.ssh/authorized_keys /home/deploy/.ssh/
chown -R deploy:deploy /home/deploy/.ssh
chmod 700 /home/deploy/.ssh
chmod 600 /home/deploy/.ssh/authorized_keys

# Disable password auth
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl restart ssh
```

## 3. UFW (secondary firewall on the box)

```bash
ufw default deny incoming
ufw default allow outgoing
ufw allow from <YOUR_IP> to any port 22 proto tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
```

Note: Docker bypasses ufw by writing iptables rules directly.
The Hetzner Cloud Firewall is the primary guard for this reason.
Do NOT expose Postgres (5432) or Redis (6379) ports in Docker — they
should only be reachable via the internal Docker network (`kamal` network).

## 4. Fail2ban

```bash
apt-get install -y fail2ban

cat > /etc/fail2ban/jail.local << 'EOF'
[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
findtime = 600
EOF

systemctl enable fail2ban
systemctl start fail2ban
```

## 5. Docker

Kamal can install Docker automatically on first `kamal setup`, but if you
want to do it manually:

```bash
curl -fsSL https://get.docker.com | sh
usermod -aG docker deploy
```

## 6. Data Directories

Create directories for persistent accessory data:

```bash
mkdir -p /home/deploy/tramline-db-data
mkdir -p /home/deploy/tramline-redis-data
mkdir -p /home/deploy/tramline-portainer-data
chown -R deploy:deploy /home/deploy/tramline-*
```

## 7. DNS

Point these records to `<HETZNER_IP>`:

| Record | Domain       | Value          |
|--------|-------------|----------------|
| A      | tramline.dev | `<HETZNER_IP>` |
| A      | tramline.in  | `<HETZNER_IP>` |

Lower TTL to 60s before migration, raise to 3600 after.

## 8. GitHub Secrets

Add these secrets to the GitHub repository (Settings > Secrets > Actions):

**Infrastructure:**
- `HETZNER_IP` — server IP address
- `SSH_PRIVATE_KEY` — deploy user's private key

**Registry:**
- `KAMAL_REGISTRY_USERNAME` and `KAMAL_REGISTRY_PASSWORD` are derived
  from `github.actor` and `GITHUB_TOKEN` automatically in the workflow

**Database:**
- `DATABASE_URL` — `postgresql://user:pass@tramline-db:5432/tramline_production`
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `POSTGRES_DB` — `tramline_production`

**Redis:**
- `REDIS_URL` — `redis://tramline-redis:6379/0`
- `DEFAULT_REDIS_URL` — same as REDIS_URL
- `SESSION_REDIS_URL` — `redis://tramline-redis:6379/1`
- `SIDEKIQ_REDIS_URL` — `redis://tramline-redis:6379/2`

**App:**
- `RAILS_MASTER_KEY`
- `HOST_NAME` — `tramline.dev`
- `DESCOPE_PROJECT_ID`
- `DESCOPE_MANAGEMENT_KEY`
- `APPLELINK_URL` — `http://tramline-applelink:9292`
- `SENTRY_DSN`
- `FRONTEND_SENTRY_DSN`
- `SENTRY_SECURITY_HEADER_ENDPOINT`
- `X_MONITOR_ALLOWED`
- `ARTIFACT_BUILDS_BUCKET_NAME`
- `APP_REDIRECT_MAPPING_JSON`
- `DISALLOWED_SIGN_UP_DOMAINS`
- `CSP_CONNECT_SRC_URIS`

## 9. First Deploy

```bash
# From your local machine (with Kamal installed and SSH key configured)
export HETZNER_IP=<your-ip>

# Bootstrap the server and deploy everything
kamal setup

# Boot accessories (Postgres, Redis, Applelink, Portainer)
kamal accessory boot all

# Deploy the app
kamal deploy
```

## 10. Data Migration (one-time)

1. Lower DNS TTL to 60s (1 day before)
2. Stop Render services (web + jobs)
3. Dump and restore:
   ```bash
   pg_dump <RENDER_DATABASE_URL> | psql <HETZNER_DATABASE_URL>
   ```
4. Flip DNS to Hetzner IP
5. Verify app is healthy
6. Raise DNS TTL back to 3600

## 11. Ongoing Operations

```bash
# Deploy latest
kamal deploy

# View logs
kamal app logs -f
kamal app logs -f --role worker

# Rails console
kamal app exec -i 'bin/rails console'

# Reboot an accessory
kamal accessory reboot <name>

# Check app status
kamal details
```

## 12. Backups

Set up automated Postgres backups. A simple cron on the server:

```bash
# /etc/cron.d/tramline-backup
0 3 * * * deploy docker exec tramline-db pg_dump -U postgres tramline_production | gzip > /home/deploy/backups/tramline-$(date +\%Y\%m\%d).sql.gz
```

Keep at least 7 days of backups. Consider also using Hetzner snapshots
for full server backups (available via the Cloud console or API).
