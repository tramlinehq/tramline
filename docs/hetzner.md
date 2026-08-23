# Hetzner Bare-Metal Setup

## Servers

| Environment | Machine | vCPU | RAM | Cost |
|-------------|---------|------|-----|------|
| Production | CPX42 | 8 | 16 GB | ~€70/mo |
| Staging | CX33 | 4 | 8 GB | ~€9/mo |

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

`kamal setup` bootstraps Docker on a fresh box, but it does so over SSH as the
`deploy` user, and the install needs root — so `deploy` must have
**passwordless sudo**. The hardened user from §2 is only in the `sudo` group,
so a non-interactive `kamal setup` would stall on a password prompt. Grant it:

```bash
echo 'deploy ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/deploy
sudo chmod 440 /etc/sudoers.d/deploy
```

Alternatively, install Docker manually and skip the passwordless-sudo grant —
`kamal setup` then sees Docker already present:

```bash
curl -fsSL https://get.docker.com | sh
usermod -aG docker deploy   # kamal runs docker as deploy; re-login to apply
```

**Pin the docker group GID before installing Docker.** Otherwise it's
assigned whatever GID is free, which makes Netdata's `PGID` host-specific.
Creating the group with a fixed GID first keeps config identical across boxes
(the netdata accessory defaults `PGID` to **989**). Use 989, **not 999** — 999
is taken by `systemd-journal` on trixie. Verify it's free first:

```bash
getent group 989 || groupadd -g 989 docker   # then install Docker; it reuses this group
```

If a box already has docker on a different GID (`getent group docker`), either
`groupmod -g 989 docker && systemctl restart docker`, or leave it and override
per destination via `NETDATA_DOCKER_GID` (shell env at deploy) or a
`netdata.env.clear.PGID` entry in that destination's overlay.

### Kernel setting for Redis

Redis warns on startup unless memory overcommit is enabled — without it a
background save (RDB) or AOF rewrite can fail its fork under memory pressure:

```
WARNING Memory overcommit must be enabled! ... add 'vm.overcommit_memory = 1'
```

This is a **host** kernel setting (shared by all containers), so set it on the
box once:

```bash
echo 'vm.overcommit_memory = 1' | sudo tee /etc/sysctl.d/99-redis.conf
sudo sysctl --system    # apply now, no reboot needed
```

Matters most for `redis-sidekiq` (AOF rewrite forks); `redis-cache` runs
`--save ""` so it never forks, but the warning is emitted regardless.

## 6. Data Directories

Kamal creates the accessory data directories itself on first boot, nesting
them under a per-accessory folder: a `directories: foo-data:/data` entry
mounts `~/<accessory-container-name>/foo-data`, e.g.

| Accessory     | Host path                                        |
|---------------|--------------------------------------------------|
| db            | `~/tramline-db/tramline-db-data`                 |
| redis-cache   | `~/tramline-redis-cache/tramline-redis-cache-data` |
| redis-sidekiq | `~/tramline-redis-sidekiq/tramline-redis-sidekiq-data` |
| dozzle        | `~/tramline-dozzle/tramline-dozzle-data`         |

Dozzle is the one that needs a file in place *before* it boots: with
`DOZZLE_AUTH_PROVIDER=simple` it exits (crash-looping) unless it finds
`/data/users.yml`. Note the nested path — putting it in
`~/tramline-dozzle-data/` instead will NOT be mounted:

```bash
mkdir -p /home/deploy/tramline-dozzle/tramline-dozzle-data
sudo docker run --rm amir20/dozzle generate admin --password '<pick-a-password>' \
  --name "Admin" > /home/deploy/tramline-dozzle/tramline-dozzle-data/users.yml
```

(`sudo` because the hardened `deploy` user isn't in the `docker` group; the
redirect still writes the file as `deploy`.)

## 7. DNS

Point these records to `<HETZNER_IP>`:

| Record | Domain            | Value          |
|--------|-------------------|----------------|
| A      | tramline.dev      | `<HETZNER_IP>` |
| A      | tramline.in       | `<HETZNER_IP>` |
| A      | logs.tramline.dev | `<HETZNER_IP>` |

Lower TTL to 60s before migration, raise to 3600 after.

`logs.tramline.dev` fronts Dozzle (kamal-proxy terminates TLS and issues a
Let's Encrypt cert for it automatically).

## 8. Secrets model (local vs CI)

Kamal loads secret files in order, skipping any that are absent, with later
files overriding earlier ones:

1. `.kamal/secrets-common` — **committed**, reference-only (`KEY=$KEY`, no
   literal values). Lists every key any destination needs.
2. `.kamal/secrets.<destination>` — **gitignored**, real literal values.

This gives one manifest that works both ways:

- **Local** — `.kamal/secrets.staging` exists on your machine and overrides
  the references, so `kamal … -d staging` uses your literal values.
- **CI** — the gitignored file isn't in the checkout, so `secrets-common`'s
  `$VARS` resolve straight from the environment, which the workflow populates
  from GitHub Actions secrets.

When you add a new secret, add a `KEY=$KEY` line to `secrets-common`, the real
value to your local `secrets.<destination>`, and (for CI) a GitHub Actions
secret + a line in the workflow's `env:` block.

### GitHub Secrets

Add these secrets to the GitHub repository (Settings > Secrets > Actions):

**Infrastructure:**
- `HETZNER_IP` — server IP address
- `HETZNER_SSH_PRIVATE_KEY` — deploy user's private key. Set at **repo level**
  (not per-environment): it's the same CI key for every box, so one shared
  secret keeps it out of each environment's list. `HETZNER_IP` stays per-env.

**Registry:**
- `KAMAL_REGISTRY_USERNAME` and `KAMAL_REGISTRY_PASSWORD` are derived
  from `github.actor` and `GITHUB_TOKEN` automatically in the workflow

**Database:**
- `DATABASE_URL` — `postgresql://user:pass@tramline-db:5432/tramline_production`
- `POSTGRES_USER`
- `POSTGRES_PASSWORD`
- `POSTGRES_DB` — `tramline_production`

**Redis:**
- `REDIS_URL` — `redis://tramline-redis-cache:6379/0`
- `DEFAULT_REDIS_URL` — same as REDIS_URL
- `SESSION_REDIS_URL` — `redis://tramline-redis-cache:6379/1`
- `SIDEKIQ_REDIS_URL` — `redis://tramline-redis-sidekiq:6379/0`

**App:**
- `RAILS_MASTER_KEY`
- `HOST_NAME` — `tramline.dev`
- `DESCOPE_PROJECT_ID`
- `DESCOPE_MANAGEMENT_KEY`
- `APPLELINK_URL` — `http://tramline-applelink:4000`
- `SENTRY_DSN`
- `FRONTEND_SENTRY_DSN`
- `SENTRY_SECURITY_HEADER_ENDPOINT`
- `X_MONITOR_ALLOWED`
- `ARTIFACT_BUILDS_BUCKET_NAME`
- `APP_REDIRECT_MAPPING_JSON`
- `DISALLOWED_SIGN_UP_DOMAINS`
- `CSP_CONNECT_SRC_URIS`

## 9. First Deploy

### Local toolchain

Deploys run from your machine (or CI). Locally you need Ruby matching
`.ruby-version` (3.4.9) and the kamal gem:

```bash
asdf install ruby 3.4.9      # if not already installed
gem install kamal            # kamal 2.x; runs the amd64 build via qemu locally
```

The **`KAMAL_REGISTRY_PASSWORD`** (ghcr push/pull) must be a **classic** PAT
with `write:packages`, or a `gh auth refresh -s write:packages` token —
**not** a fine-grained PAT. Fine-grained tokens 403 on org-owned container
packages even with Packages: write, because ghcr inherits permissions from a
linked repo; `Dockerfile` sets `org.opencontainers.image.source` to link
the package, but a classic token is still the reliable choice. (CI uses the
built-in `GITHUB_TOKEN` and doesn't hit this.)

### Running it

`kamal setup` is the whole first run in one command: it installs Docker,
boots kamal-proxy, boots **all** accessories (Postgres, Redis ×2, Applelink,
Dozzle, Netdata), then builds, pushes, and deploys the app. You do NOT run
`kamal accessory boot` or `kamal deploy` separately on a first run — those are
for later, incremental changes.

```bash
# From your local machine (with Kamal installed and SSH key configured)
export HETZNER_IP=<your-ip>
export KAMAL_REGISTRY_PASSWORD=<ghcr-token>   # read:packages, to pull the image

# Production (config/deploy.yml → tramline.dev):
kamal setup

# Staging (config/deploy.yml + config/deploy.staging.yml → tramline.site):
kamal setup -d staging
```

Prerequisites before the first `kamal setup`:

- `.kamal/secrets` (or `.kamal/secrets.staging`) filled in — never committed.
- DNS for the app host **and** `logs.<host>` pointing at the server, so
  kamal-proxy can issue Let's Encrypt certs.
- Dozzle's `users.yml` created on the box **at the mounted path**
  `~/tramline-dozzle/tramline-dozzle-data/users.yml` (§6) **before the first
  `kamal setup`** — the `dozzle` accessory crash-loops without it. Generating it
  uses `docker run amir20/dozzle …`, so Docker must already be on the box
  (install it manually per §5, or generate the file on another machine, then
  copy it over).
- `NETDATA_CLAIM_TOKEN` in the secrets file (app.netdata.cloud → Connect
  Nodes), or Netdata boots but won't appear in Cloud.

Later, incremental operations (see §11): `kamal deploy` to ship new code,
`kamal accessory reboot <name>` to restart one accessory.

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

### Dozzle (log viewer)

Dozzle is served at `https://logs.tramline.dev` behind its built-in simple
auth. Log in with the credentials from `users.yml` (generated in step 6).
To rotate them, regenerate `users.yml` on the host and
`kamal accessory reboot dozzle`.

### Netdata (metrics with history)

Dozzle shows live logs but its metrics are real-time only, with no retention.
Netdata covers host + container metrics with history, kept in
`/var/lib/netdata` on a persistent volume so it survives restarts.

It is intentionally **not** exposed through kamal-proxy. The agent dashboard
has no built-in authentication, and it doesn't need inbound access: claiming
the node opens an **outbound** connection to Netdata Cloud, so you view
metrics — SSO-gated — at [app.netdata.cloud](https://app.netdata.cloud).

Set `NETDATA_CLAIM_TOKEN` in the secrets file first (app.netdata.cloud →
Space settings → Connect Nodes), then:

```bash
kamal accessory boot netdata -d staging
```

The container also publishes `127.0.0.1:19999` for local debugging:

```bash
ssh -L 19999:localhost:19999 deploy@<HETZNER_IP>
# then open http://localhost:19999
```

Retention is governed by the dbengine settings in `/etc/netdata/netdata.conf`
(also on a persistent volume, so edits survive). Defaults give roughly days at
per-second resolution and up to a year at coarser tiers.

## 12. Backups

Set up automated Postgres backups. A simple cron on the server:

```bash
# /etc/cron.d/tramline-backup
0 3 * * * deploy docker exec tramline-db pg_dump -U postgres tramline_production | gzip > /home/deploy/backups/tramline-$(date +\%Y\%m\%d).sql.gz
```

Keep at least 7 days of backups. Consider also using Hetzner snapshots
for full server backups (available via the Cloud console or API).
