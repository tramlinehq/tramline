# Tailscale Funnel Setup

Tramline uses Tailscale Funnel for public URLs and webhooks. This works for both the main repository and worktrees, allowing multiple instances to run simultaneously with their own public URLs.

## Why Tailscale Funnel?

- **Free for development use** - no account limits like ngrok
- **Multiple simultaneous tunnels** - each worktree can have its own public URL
- **Persistent URLs** - URLs don't change between sessions (unlike ngrok free)
- **Better performance** - uses WireGuard protocol
- **Runs in Docker** - no need to install anything on your host machine

## Setup (One-time)

### 1. Create a Tailscale Account

Visit [https://login.tailscale.com/start](https://login.tailscale.com/start) and create a free account.

### 2. Generate an Auth Key

1. Go to [https://login.tailscale.com/admin/settings/keys](https://login.tailscale.com/admin/settings/keys)
2. Click "Generate auth key"
3. **Important settings:**
   - Enable "Reusable" (so you can use it for multiple worktrees)
   - Enable "Ephemeral" (auto-cleanup when container stops)
   - Optionally set an expiration (90 days recommended)
4. Copy the generated key (starts with `tskey-auth-...`)

### 3. Add Auth Key to .env.development

Add this line to your worktree's `.env.development`:

```bash
TAILSCALE_AUTHKEY=tskey-auth-xxxxxxxxxxxxxxxxxxxxxxxxxx
```

**Security Note:** The `.env.development` file is gitignored, so your auth key won't be committed to the repository.

## Usage

### Starting with Tailscale

Simply start your environment as normal:

**Main repository:**
```bash
just start
```

**Worktree:**
```bash
just start
```

The Tailscale container will:
1. Connect to your Tailscale network (tailnet)
2. Automatically start a Funnel exposing the web port
3. Print a message when ready

### Finding Your Public URL

**Option 1: Use the helper script (Recommended)**

```bash
bin/get-tunnel-url
```

Or use the Just recipe to see all your URLs:
```bash
just ports
```

This will show both your local URL and your Tailscale Funnel URL.

**Option 2: Check the Tailscale container logs**

Main repository:
```bash
docker compose logs tailscale
```

Worktree:
```bash
docker compose -f compose.yml -f compose.worktree.yml logs tailscale
```

**Option 3: Use the Tailscale admin console**

Visit [https://login.tailscale.com/admin/machines](https://login.tailscale.com/admin/machines) to see all your devices and their Funnel URLs.

**Expected URLs:**
- Main repository: `https://tramline-main.<your-tailnet>.ts.net`
- Worktree: `https://tramline-<worktree-name>.<your-tailnet>.ts.net`
  - Example: `https://tramline-sad-galileo.<your-tailnet>.ts.net`

### Environment Variables

The `.env.development` file is configured to **automatically fetch your Tailscale Funnel URL**:

```bash
TUNNELED_HOST_NAME=$(bin/get-tunnel-url)
WEBHOOK_HOST_NAME=$(bin/get-tunnel-url)
```

This means:
- ✅ If Tailscale is running → uses your Funnel URL
- ✅ If Tailscale is not running → falls back to localhost
- ✅ Works in both main repo and worktrees
- ✅ No manual configuration needed

**Optional: Use static URLs instead**

If you prefer static URLs (doesn't change, won't query Tailscale on every shell start), set them manually in `.env.development`:

```bash
# Main repository
TUNNELED_HOST_NAME=https://tramline-main.your-tailnet.ts.net
WEBHOOK_HOST_NAME=https://tramline-main.your-tailnet.ts.net

# Or for a worktree
TUNNELED_HOST_NAME=https://tramline-sad-galileo.your-tailnet.ts.net
WEBHOOK_HOST_NAME=https://tramline-sad-galileo.your-tailnet.ts.net
```

## Running Multiple Instances Simultaneously

Each instance (main repo + worktrees) automatically gets its own Tailscale Funnel URL:

- Main repository → `https://tramline-main.your-tailnet.ts.net`
- Worktree `sad-galileo` → `https://tramline-sad-galileo.your-tailnet.ts.net`
- Worktree `happy-newton` → `https://tramline-happy-newton.your-tailnet.ts.net`

All instances can run simultaneously and receive webhooks independently!

## Troubleshooting

### Tailscale container keeps restarting

Check the logs:

Main repository:
```bash
docker compose logs tailscale
```

Worktree:
```bash
docker compose -f compose.yml -f compose.worktree.yml logs tailscale
```

Common issues:
- **"TAILSCALE_AUTHKEY not set"** - Add the auth key to `.env.development`
- **"authentication failed"** - Your auth key may have expired, generate a new one
- **"funnel: not available"** - Funnel requires a Tailscale account with HTTPS enabled

### Can't access the public URL

1. Verify Tailscale is running:
   - Main: `docker compose ps tailscale`
   - Worktree: `docker compose -f compose.yml -f compose.worktree.yml ps tailscale`

2. Check that Funnel is active:
   - Main: `docker compose exec tailscale tailscale funnel status`
   - Worktree: `docker compose -f compose.yml -f compose.worktree.yml exec tailscale tailscale funnel status`

3. Make sure your web service is running:
   - Main: `https://localhost:3000`
   - Worktree: Check port with `just ports`

### Want to disable Tailscale temporarily

Remove or comment out `TAILSCALE_AUTHKEY` from `.env.development`. The container will start but won't connect to Tailscale.

## Alternative Options

### Option 1: Local URLs Only (No Webhooks)

If you don't need webhooks, skip Tailscale entirely:

1. Don't set `TAILSCALE_AUTHKEY` in `.env.development`
2. Access the app locally:
   - Main: `https://localhost:3000`
   - Worktree: `https://localhost:<PORT>` (see `just ports`)
3. Set webhook URLs to localhost (won't work for external webhooks):
   ```bash
   # Main repo
   TUNNELED_HOST_NAME=https://localhost:3000
   WEBHOOK_HOST_NAME=https://localhost:3000

   # Worktree
   TUNNELED_HOST_NAME=https://localhost:3542
   WEBHOOK_HOST_NAME=https://localhost:3542
   ```

### Option 2: Use Ngrok (Legacy)

Ngrok is still available but deprecated. To use it:

1. Start services with the ngrok profile:
   ```bash
   docker compose --profile ngrok up
   ```

2. Set ngrok authtoken in `.env.development`:
   ```bash
   NGROK_AUTHTOKEN=your-ngrok-token
   ```

3. Use ngrok dynamic URLs:
   ```bash
   TUNNELED_HOST_NAME=$(curl -s ngrok:4040/api/tunnels | jq -r .tunnels\[0\].public_url)
   WEBHOOK_HOST_NAME=$(curl -s ngrok:4040/api/tunnels | jq -r .tunnels\[0\].public_url)
   ```

**Note:** Ngrok free tier only allows one agent session, so you can't run multiple instances simultaneously.

## Security Notes

- **Auth keys are sensitive** - Don't commit them to git (`.env.development` is gitignored)
- **Use ephemeral keys** - They auto-cleanup when containers stop
- **Set expiration** - 90 days is reasonable for development keys
- **One key per developer** - Each team member should use their own Tailscale account and auth key
- **Revoke old keys** - Check [https://login.tailscale.com/admin/settings/keys](https://login.tailscale.com/admin/settings/keys) periodically

## More Info

- Tailscale Funnel docs: [https://tailscale.com/kb/1223/funnel/](https://tailscale.com/kb/1223/funnel/)
- Docker container usage: [https://tailscale.com/kb/1282/docker/](https://tailscale.com/kb/1282/docker/)
