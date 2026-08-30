# BI queries (ex-PostHog)

Business-intelligence queries we used to run in PostHog against the mirrored
Postgres data. The PostHog Data Warehouse Postgres sync was retired after the
Hetzner migration (PostHog kept only app-side event tracking), so these are
preserved here to run **directly against the Tramline Postgres**.

They were originally written in PostHog's ClickHouse dialect; the versions below
are translated to plain Postgres:

- dropped the `postgres.` warehouse schema prefix (our tables live in `public`);
- `now() - toIntervalDay(N)` → `now() - interval 'N days'`;
- `replaceRegexpAll(x, re, '')` → `regexp_replace(x, re, '', 'g')`;
- the templated `{variables.interval_day}` → a literal `interval '… days'` you edit.

## Running them

Open a SQL session against production and paste a query:

```bash
kamal app exec -d production --reuse 'bin/rails dbconsole'
```

(or `psql "$DATABASE_URL"` from inside the `db` accessory). These only read —
adjust the `interval '… days'` windows to taste.

---

## Active orgs (last 60 days)

Orgs with the most releases scheduled in the window, with their owner.

```sql
SELECT org, owner, releases
FROM (
  SELECT o.name       AS org,
         o.created_by AS owner,
         COUNT(r.id)  AS releases
  FROM organizations o
  INNER JOIN apps     a ON a.organization_id = o.id
  INNER JOIN trains   t ON t.app_id = a.id
  INNER JOIN releases r ON r.train_id = t.id
  WHERE r.scheduled_at > now() - interval '60 days'
  GROUP BY o.name, o.created_by
) virtual_table
ORDER BY releases DESC
LIMIT 1000;
```

## Unique normalized contributors per org

Distinct commit authors per org over the window, normalizing author names
(lowercase, strip non-alphanumerics) so `Jane Doe` / `jane.doe` collapse to one.
This is the per-committer signal Tramline's old per-seat billing was based on.

```sql
SELECT org_name, count
FROM (
  SELECT o.name AS org_name,
         COUNT(DISTINCT regexp_replace(lower(c.author_name), '[^a-z0-9]', '', 'g')) - 1 AS count
  FROM commits          c
  INNER JOIN releases   r ON c.release_id = r.id
  INNER JOIN trains     t ON t.id = r.train_id
  INNER JOIN apps       a ON a.id = t.app_id
  INNER JOIN organizations o ON o.id = a.organization_id
  WHERE c.timestamp > now() - interval '60 days'
  GROUP BY o.name
) virtual_table
ORDER BY count DESC
LIMIT 1000;
```

> The `- 1` is carried over from the original query. `COUNT(DISTINCT …)` ignores
> NULL authors but still counts one bucket for commits whose author normalizes to
> the empty string (no usable `author_name`); the `- 1` discounts that bucket.
> Drop it for the raw distinct count.

## Org activity levels

One row per org with counts across the hierarchy and the last release time — a
broad "how active is each org" overview.

```sql
SELECT
  o.slug       AS org_slug,
  o.created_at AS org_created_at,
  COUNT(DISTINCT a.id) AS app_count,
  COUNT(DISTINCT i.id) AS integration_count,
  COUNT(DISTINCT t.id) AS train_count,
  COUNT(DISTINCT r.id) AS release_count,
  MAX(r.scheduled_at)  AS last_release_at
FROM organizations o
LEFT JOIN apps         a ON a.organization_id = o.id
LEFT JOIN integrations i ON i.app_id = a.id
LEFT JOIN trains       t ON t.app_id = a.id
LEFT JOIN releases     r ON r.train_id = t.id
GROUP BY 1, 2
ORDER BY 6 DESC, 3 DESC, 4 DESC, 5 DESC;
```

> No time filter — this scans every org; fine as an occasional BI query, not
> something to run on a hot path.
