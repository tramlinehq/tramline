# Tramline Local Development Setup

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/), [OrbStack](https://orbstack.dev), or [Colima](https://github.com/abiosoft/colima)
- [just](https://github.com/casey/just) command runner

```bash
brew install just
```

### Colima (alternative to Docker Desktop)

```bash
brew install colima docker docker-compose
colima start --cpu 4 --memory 8 --disk 60
```

If using Colima, ensure `~/.docker/config.json` includes:

```json
{
  "cliPluginsExtraDirs": [
    "/opt/homebrew/lib/docker/cli-plugins"
  ]
}
```

### Applelink (optional)

[Applelink](https://github.com/tramlinehq/applelink) is a separate service for App Store integration. If you need it, clone it into a **sibling** directory (not inside Tramline):

```
parent-directory/
  applelink/
  tramline/
```

The Docker Compose setup includes it automatically. Skip this if you're not working on App Store features.

---

## First-Time Setup

```bash
# 1. Copy env file
cp .env.development.sample .env.development

# 2. Generate Rails credentials (interactive — follow the prompts)
just pre-setup

# 3. Start all services (postgres, redis, web, worker, css, localtunnel)
just start
```

The `setup` service runs automatically on first start and will:
- Install gems
- Create and migrate the database
- Seed test users
- Generate SSL certificates

### Credentials

If you're a **trusted contributor**, ask an existing developer for the dev `master.key`. Place it in `config/master.key` or set `RAILS_MASTER_KEY` in `.env.development`.

If you're a **new external contributor**, run `just pre-setup` to generate your own credentials.

---

## Access

Open **https://tramline.local.gd:3000** in your browser.

### Seed Users

| Role | Email | Password |
|------|-------|----------|
| Admin | `admin@tramline.app` | `why aroma enclose startup` |
| Owner | `owner@tramline.app` | `why aroma enclose startup` |
| Developer | `developer@tramline.app` | `why aroma enclose startup` |

The **Owner** account has a pre-configured organization. Use it to explore the full UI.

---

## Common Commands

```bash
just start              # Start all services
just stop               # Stop all services
just restart             # Restart web service
just rails console       # Open Rails console
just spec                # Run all tests
just spec spec/models/   # Run specific tests
just lint                # Run linters
just devlog              # Tail application logs
just bglog               # Tail Sidekiq worker logs
just attach              # Attach to web (for pry debugging)
just shell               # Open bash in web container
just --list              # See all available commands
```

### Adding or Updating Gems

```bash
just bundle add <gem>       # Add a new gem
just bundle update <gem>    # Update a gem
```

Restart web/worker containers after gem changes.

---

## Services & Ports

| Service | Port | Description |
|---------|------|-------------|
| Web (Puma) | 3000 (HTTPS) | Rails application |
| PostgreSQL | 5442 | Database (mapped from 5432) |
| Redis | 6389 | Cache & job queue (mapped from 6379) |
| Applelink | 4000 | Apple API service (optional) |

---

## Webhooks / Tunnel

Webhooks from external services (GitHub, GitLab, etc.) need a public URL. The Docker setup includes an ngrok-based tunnel.

One-time setup:
1. Sign up at [ngrok.com](https://ngrok.com)
2. Get your authtoken from [dashboard.ngrok.com/get-started/your-authtoken](https://dashboard.ngrok.com/get-started/your-authtoken)

Configure in `.env.development`:

```env
LOCALTUNNEL_AUTHTOKEN=<your-ngrok-token>
LOCALTUNNEL_DOMAIN=<optional-reserved-domain>
```

Run `just ports` to see your tunnel URL. Set `LOCALTUNNEL_DISABLED=true` to disable tunneling.

---

## Integrations

Tramline is integration-heavy. For a basic development setup, only **GitHub** is necessary.

1. [Create a GitHub App](https://docs.github.com/en/apps/creating-github-apps/registering-a-github-app/registering-a-github-app)
2. Edit credentials:
   ```bash
   just rails credentials:edit
   ```
3. Add this section:
   ```yaml
   integrations:
     github:
       app_name: <your-app-name>
       app_id: <your-app-id>
       private_pem: |
         <your-private-key>
   ```
4. Restart the web service: `just restart`

Without integrations you can still explore the UI — you just can't run an actual release flow.

---

## Git Worktrees

Tramline supports running multiple worktrees simultaneously. Each worktree gets a unique port based on its directory name.

The main repository must be running first (`just start`). Worktrees share the main repo's postgres, redis, and applelink containers.

```bash
# From the main repo:
git worktree add ../tramline-feature-branch feature-branch
bin/setup.worktree ../tramline-feature-branch

# Start the worktree:
cd ../tramline-feature-branch
just start
just ports   # See assigned port
```

Each worktree is accessible at `https://tramline.local.gd:<assigned-port>`.

---

## Useful URLs

| URL | Description |
|-----|-------------|
| https://tramline.local.gd:3000 | Application |
| https://tramline.local.gd:3000/letter_opener | Captured emails |
| https://tramline.local.gd:3000/sidekiq | Background job dashboard |
| https://tramline.local.gd:3000/flipper | Feature flags |

---

## Debugging

Attach to a running container for `pry` debugging:

```bash
just attach        # Attach to web (default)
just attach worker # Attach to worker
```

Detach with `Ctrl+D`. Do **not** kill the process — it will stop the container.

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `pg_query` gem won't compile (strchrnul error) | `just bundle update pg_query` (need v6.2.2+) |
| `Could not open library 'vips.42'` | `brew install vips` |
| `tailwind.css is not present in the asset pipeline` | `just restart css` |
| 500 error on login (GCP credentials) | Add dummy `dependencies.gcp` block to credentials |
