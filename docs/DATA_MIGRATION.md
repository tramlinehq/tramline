# Data migration: Render → Hetzner

Faithful Postgres transfer from the Render-hosted database to the Hetzner
(Kamal) box. Both sides run **Postgres 14** and the **same Rails 8.1 schema**,
so this is a pure dump/restore — no schema catch-up, no anonymization. (The
`anonymize:*` rake tasks are a *different* tool, for seeding staging with
scrubbed prod data; they are not part of a migration.)

## Why it runs inside the `db` accessory

The `db` accessory container is the only place that reaches **both** ends:

- it *is* the Hetzner Postgres, so the target is `localhost`, and
- it has outbound network to Render's external endpoint, and
- it ships the matching pg14 client tools (`pg_dump`/`psql`).

The Hetzner Postgres is **not** published on a host port (it lives on the
private Kamal Docker network), so you cannot pipe into it from your laptop —
run everything through `kamal accessory exec db`.

`POSTGRES_USER` (`tramline`) is a **superuser** in the official `postgres`
image, so it can `DROP`/`CREATE DATABASE`.

## Guaranteeing a clean target

We **drop and recreate the database**, then restore into an empty DB. This is
stronger than `pg_dump --clean`, which only drops objects contained in the
dump and would leave behind any table/row that exists on Hetzner but not in the
source. Recreating the database leaves **zero** residual seed data by
construction.

`DROP DATABASE ... WITH (FORCE)` (pg13+) terminates any lingering connections,
but we still stop the app first so it isn't reconnecting and erroring mid-restore.

---

## A. Staging migration (the dress rehearsal)

Get the Render **staging** *external* connection string from the Render
dashboard first (the internal `...-internal` host won't resolve from Hetzner).

```bash
export HETZNER_IP=167.235.157.31
export DEST=staging
export TARGET_DB=tramline_staging     # matches POSTGRES_DB for this destination
export RENDER_URL='postgresql://USER:PASS@RENDER_STAGING_HOST:5432/RENDER_STAGING_DB'
```

**1. Quiesce the target** — stop the app so nothing writes mid-restore:

```bash
kamal app stop -d $DEST
```

**2. Drop + recreate the target DB, then restore** — one exec, inside the db
container. Connects to the `postgres` maintenance DB to drop the target, then
pipes the dump straight in. `ON_ERROR_STOP=1` aborts loudly on any failure
instead of leaving a half-restored DB:

```bash
kamal accessory exec db -d $DEST --reuse "bash -lc '
  set -euo pipefail
  psql -U tramline -d postgres -v ON_ERROR_STOP=1 \
    -c \"DROP DATABASE IF EXISTS ${TARGET_DB} WITH (FORCE);\" \
    -c \"CREATE DATABASE ${TARGET_DB} OWNER tramline;\"
  pg_dump --no-owner --no-privileges \"${RENDER_URL}\" \
  | psql -U tramline -d ${TARGET_DB} -v ON_ERROR_STOP=1
'"
```

**3. Bring it back up and smoke-test:**

```bash
kamal app boot -d $DEST
```

Then hit `https://tramline.site`, log in, and spot-check a few records
(orgs/apps/trains/releases) against Render.

### What makes it faithful

- **Sequences travel in the dump** → auto-increment IDs continue exactly where
  Render left off; no PK collisions on newly created records.
- **`--no-owner --no-privileges`** → objects re-own to `tramline` on Hetzner
  regardless of Render's role names.
- **Extensions** (`pgcrypto`, `pg_trgm`) are in the dump and present in the
  `postgres:14` image, so `CREATE EXTENSION` succeeds.
- **Same pg major (14 ↔ 14)** → no dump-format incompatibility.
- **Same Rails 8.1 schema on both sides** → no `db:migrate` needed afterward.
  (If you ever migrate from an older-schema source, run
  `kamal app exec -d $DEST "bin/rails db:migrate"` after the restore.)

---

## B. Production cutover

Identical procedure, with two additions: a **reversible backup** of the Hetzner
side first, and a real **downtime window** (this is the live site).

```bash
export HETZNER_IP=<prod-box-ip>
export DEST=production
export TARGET_DB=tramline_production   # matches prod POSTGRES_DB
export RENDER_URL='postgresql://USER:PASS@RENDER_PROD_HOST:5432/RENDER_PROD_DB'
```

**1. Stop the app** (begins the downtime window):

```bash
kamal app stop -d $DEST
```

**2. Back up the current Hetzner DB first** — so the cutover is reversible if
the restore goes wrong. Writes into the db accessory's mounted data dir:

```bash
kamal accessory exec db -d $DEST --reuse "bash -lc '
  pg_dump -Fc --no-owner --no-privileges -U tramline -d ${TARGET_DB} \
    -f /var/lib/postgresql/data/pre-cutover-\$(date +%Y%m%d-%H%M).dump
'"
```

**3. Drop + recreate + restore** (same as staging step 2):

```bash
kamal accessory exec db -d $DEST --reuse "bash -lc '
  set -euo pipefail
  psql -U tramline -d postgres -v ON_ERROR_STOP=1 \
    -c \"DROP DATABASE IF EXISTS ${TARGET_DB} WITH (FORCE);\" \
    -c \"CREATE DATABASE ${TARGET_DB} OWNER tramline;\"
  pg_dump --no-owner --no-privileges \"${RENDER_URL}\" \
  | psql -U tramline -d ${TARGET_DB} -v ON_ERROR_STOP=1
'"
```

**4. Boot, smoke-test, then flip DNS** to the Hetzner box. Keep the pre-cutover
dump until the new box has proven itself.

### Rollback

If the restore is bad, restore the backup taken in step 2 into a freshly
recreated DB (`pg_restore --clean --if-exists`), or simply re-point DNS at
Render while you investigate — Render is untouched by this procedure (we only
ever **read** from it).

---

## Notes

- **Password in the command string** appears in the box's shell history and
  process list during the run. For a one-off migration that's usually
  acceptable; to avoid it, dump to a file (`-Fc -f`) in a first step and
  `pg_restore` in a second.
- **Render is read-only in this flow.** Every command only `pg_dump`s from
  Render; nothing writes back. Render stays a safe fallback until DNS is flipped
  and the new box is trusted.
- **Redis is not migrated.** Cache is disposable (it re-warms); Sidekiq's queue
  should be drained before a prod cutover rather than copied — stop enqueuing,
  let the workers finish, then cut over.
