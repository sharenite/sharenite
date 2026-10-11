![License](https://img.shields.io/github/license/sharenite/sharenite?style=for-the-badge)

# Sharenite

## Local development

```bash
cp .env.example .env
docker compose up -d
bundle install
bin/rails db:prepare
bin/dev
```

`docker compose up` starts only infra (`db`, `redis`, `kafka`, `kafka-ui`).
`bin/dev` starts Rails + JS/CSS watchers.

### Dependency compatibility

Use Ruby 3.3.12 and Node 24.21.0 LTS, as pinned in `.ruby-version` and `.node-version`.
Use Yarn Classic 1.22.22 (`npm install --global yarn@1.22.22`). Docker's build stage
uses the same Node and Yarn versions and checks the Node pin before installing packages.
Rails 8.1 uses Devise 5 for browser and admin authentication. The mounted Grape 4 API
shares the existing user session through `API::Authentication`, so Playnite keeps
using the same login URL and cookies without the `grape_devise` dependency.
API JSON uses ActiveModelSerializers directly through `API::JsonFormatter`; the
forked `grape-active_model_serializers` adapter is no longer needed.
Framework defaults remain at 7.0 while newer defaults are reviewed separately;
Devise also retains its previous signing-key precedence to preserve account tokens.
Sass 1.105 and lint-staged 17 run on Node 24. Pre-commit checks hide unstaged changes
while running tasks so lint-staged does not include unrelated edits in the commit.
`yarn build:css` compiles both the main site and ActiveAdmin with Dart Sass, using
the installed ActiveAdmin gem's stylesheets. `bin/dev` watches both entrypoints.
Sprockets serves the generated CSS from `app/assets/builds`; SassC is no longer used.

## Local secrets (direnv)

Use `direnv` so deploy/install secrets are loaded automatically and never committed.

```bash
cp .envrc.example .envrc
cat > .envrc.local <<'EOF'
export KAMAL_REGISTRY_PASSWORD='...'
export KAMAL_REGISTRY_USERNAME='...'
export SHARENITE_DATABASE_PASSWORD='...'
export BUNDLE_GEMS__KARAFKA__IO='...'
export KARAFKA_PRO_LICENSE_ID='...'
export KARAFKA_UI_SECRET='...'
export IGDB_CLIENT_ID='...'
export IGDB_CLIENT_SECRET='...'
export RECAPTCHA_SITE_KEY='...'
export RECAPTCHA_SECRET_KEY='...'
export UPTIME_MONITOR_TOKEN='...'
EOF
direnv allow
```

Docker Hub auth (recommended to avoid pull-rate limits):

```bash
echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin
```

## Karafka gem update

If you need to refresh Karafka dependencies:

```bash
KARAFKA_PRO_LICENSE_ID=... BUNDLE_GEMS__KARAFKA__IO=... bundle update karafka
```

On macOS, `karafka-rdkafka` may fail to compile due to local OpenSSL linker issues. In CI/deploy (Linux, amd64) this is usually not a blocker.

## Kamal staging deploy

Staging config is in `config/deploy.staging.yml` and targets:
- Host: `sharenite.testing.xenor.ovh`
- Server: `192.168.2.73`

Required environment variables before running Kamal:

```bash
export KAMAL_REGISTRY_PASSWORD=...
export KAMAL_REGISTRY_USERNAME=...
export SHARENITE_DATABASE_PASSWORD=...
export BUNDLE_GEMS__KARAFKA__IO=...
export KARAFKA_PRO_LICENSE_ID=...
export KARAFKA_UI_SECRET=...
export IGDB_CLIENT_ID=...
export IGDB_CLIENT_SECRET=...
export RECAPTCHA_SITE_KEY=...
export RECAPTCHA_SECRET_KEY=...
export UPTIME_MONITOR_TOKEN=...
export DOCKERHUB_USERNAME=...
export DOCKERHUB_TOKEN=...
```

`POSTGRES_PASSWORD` is derived from `SHARENITE_DATABASE_PASSWORD` via `.kamal/secrets.staging`.
`DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` are optional, but recommended for authenticated Docker Hub pulls.

Deploy flow:

```bash
cp .envrc.staging.example .envrc.staging
echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin
# then SSH to 192.168.2.73 and run the same docker login command there
bin/kamal-staging setup
bin/kamal-staging deploy
```

Safer local flow (recommended if you do not have CI):

```bash
bin/deploy-staging-safe
```

This wrapper runs:
1. `kamal deploy`
2. `rails db:migrate` on staging web role
3. post-deploy checks (`db:abort_if_pending_migrations` and recent 500/schema error scan)

You can also run checks only:

```bash
bin/check-staging-health
```

Useful commands:

```bash
bin/kamal-staging app logs -f
bin/kamal-staging app exec --reuse "bin/rails db:migrate"
bin/kamal-staging app exec -i --reuse "bin/rails c"
```

## Kamal production deploy

Production config is in `config/deploy.production.yml` and currently targets:
- Host: `www.sharenite.link` (canonical)
- Server: `5.135.141.150`

Prepare env file:

```bash
cp .envrc.production.example .envrc.production
```

Set production values in `.envrc.production`, then run:

```bash
echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin
# then SSH to 5.135.141.150 and run the same docker login command there
bin/kamal-production setup
bin/kamal-production deploy
```

Safer local flow (recommended if you do not have CI):

```bash
bin/deploy-production-safe
```

This wrapper runs:
1. `kamal deploy`
2. `rails db:migrate` on production web role
3. post-deploy checks (`db:abort_if_pending_migrations` and recent 500/schema error scan)

You can also run checks only:

```bash
bin/check-production-health
```

Useful commands:

```bash
bin/kamal-production app details
bin/kamal-production app logs -f
bin/kamal-production accessory details kafka
bin/kamal-production app exec --roles=worker -- bundle exec karafka-web migrate
```

### AppSignal uptime monitor

Set `UPTIME_MONITOR_TOKEN` in the production env and configure the uptime check for `https://www.sharenite.link/` to send:

```text
X-Uptime-Monitor-Token: <UPTIME_MONITOR_TOKEN>
```

Requests with that header are counted as the dedicated `monitor:uptime` actor on the authenticated global throttle rule. The token only applies to `GET`/`HEAD /` by default; set `UPTIME_MONITOR_PATHS` to a comma-separated list if another monitored path needs the same treatment.

## Infrastructure review (2026-10-11)

Read-only checks of the running staging and production containers found:

| Service | Staging | Production | Recommended next change |
| --- | --- | --- | --- |
| PostgreSQL | 15.12, Debian 12 | 15.17, Debian 13 | Patch to 15.19, retaining the existing Debian family and data directory. |
| Redis | 7.4.8 | 7.4.8 | Patch to 7.4.11; this includes security fixes. |
| Kafka | 3.7.0, KRaft metadata 3.7-IV4 | 3.7.0, KRaft metadata 3.7-IV4 | Preserve the broker data first, then rehearse upgrading to 4.3.1 in staging. |
| Local Kafka UI | `provectuslabs/kafka-ui:latest` in Compose | Not deployed by Kamal | Replace with the maintained `ghcr.io/kafbat/kafka-ui:v1.5.0` image in a separate infrastructure change. |

PostgreSQL 15 remains supported until November 2027, so a major upgrade can be
planned separately. The verified patch tags are `postgres:15.19-bookworm` for
staging and `postgres:15.19-trixie` for production. Keeping the distribution fixed
avoids combining a database patch with a libc/collation change. See the
[PostgreSQL versioning policy](https://www.postgresql.org/support/versioning/).
Redis's patch target is `redis:7.4.11-alpine`; see the
[7.4 release notes](https://raw.githubusercontent.com/redis/redis/7.4/00-RELEASENOTES).

**Kafka persistence must be fixed before replacing its container.** Both running
brokers write to `/tmp/kraft-combined-logs`, which is outside every mounted volume.
The anonymous volume at `/var/lib/kafka/data` does not protect that configured
directory. Recreating the container can therefore lose topic data, offsets, and
cluster metadata. Both brokers use a single node and replication factor 1.
Both also publish plaintext port 9092 on all host interfaces; firewall reachability
was not assessed. Review whether the host port is needed by any external client.

Suggested maintenance sequence, staging first:

1. Verify a database restore in an isolated environment, and record current image
   digests and volume paths. Production has daily compressed SQL dumps, including
   one from October 11 (about 5.16 GB); a restore was not exercised in this review.
2. Patch PostgreSQL and Redis independently, preserving their existing bind mounts.
   Pause writers and snapshot Redis after the final writes before replacing it.
   Redis has successful RDB snapshots but AOF is disabled, and it stores sync job
   payloads as well as cache/throttle state. It must not be treated as disposable.
3. Pause sync producers and consumers, stop Kafka cleanly, and back up the stopped
   container's full log directory, including `meta.properties` and metadata logs.
   Copy it with ownership preserved to a dedicated persistent host directory and
   mount it at the existing log path. Restart **the same 3.7.0 image** first, with
   the same cluster/node IDs; verify topics, offsets, and consumer lag.
4. Rehearse the 4.3.1 broker upgrade using a separate copy of the preserved data.
   Verify the Karafka producer/consumer flow before finalizing the metadata version.
   The [Kafka upgrade guide](https://kafka.apache.org/43/getting-started/upgrade/)
   supports this KRaft upgrade path, but metadata changes can prevent downgrade.
   Retain the pre-upgrade data snapshot for rollback and plan single-broker downtime.
5. Replace the local UI with the pinned
   [Kafbat UI release](https://github.com/kafbat/kafka-ui/releases/tag/v1.5.0), and
   bind development service ports to localhost where remote access is unnecessary.

This review did not change accessory images, restart services, or modify their data.
Application deploys do not refresh already-running PostgreSQL, Redis, or Kafka
accessories; they need their own maintenance rollout.

## Production DB backup cron

This repo includes a host-level backup script for Kamal production DB accessory:

```bash
scripts/db_backup_production.sh
```

Kamal does not copy repository files to `/home/ubuntu/...` on the server.
Use the helper below to install script + cron entry on the production host:

```bash
bin/install-prod-backup-cron
```

Manual install (if needed):

```bash
scp scripts/db_backup_production.sh ubuntu@sharenite.link:/home/ubuntu/sharenite/db_backup_production.sh
ssh ubuntu@sharenite.link 'chmod +x /home/ubuntu/sharenite/db_backup_production.sh'
```

Optional overrides:
- `REMOTE_USER` (defaults to `ssh.user` from `config/deploy.production.yml`)
- `CRON_SCHEDULE` (defaults to `30 4 * * *`)
- `REMOTE_SCRIPT_PATH` (defaults to `/home/<REMOTE_USER>/sharenite/db_backup_production.sh`)
- `REMOTE_LOG_PATH` (defaults to `/home/<REMOTE_USER>/backups/sharenite/backup.log`)
- first argument: explicit host override

Defaults:
- backup dir: `~/backups/sharenite`
- file pattern: `prod_dump_YYYY-MM-DD_HH_MM_SS.sql.gz`
- retention: 7 days

Example cron (daily 04:30 server time):

```cron
30 4 * * * /home/ubuntu/sharenite/db_backup_production.sh >> /home/ubuntu/backups/sharenite/backup.log 2>&1
```

Optional env overrides in cron:
- `BACKUP_DIR` (default `~/backups`)
- `RETENTION_DAYS` (default `7`)
- `DB_NAME` (default `sharenite_production`)
- `DB_USER` (default `sharenite`)

Restore example (plain SQL dump):

```bash
gzip -dc /path/to/prod_dump_*.sql.gz | docker exec -i sharenite-db psql -U sharenite -d sharenite_production
```

## Production IGDB matching cron

The legacy cron command:

```cron
0 5 * * * docker exec ... bin/rails runner 'IgdbMatchGames.new((Date.today - 1).to_s).call'
```

is represented in app code as:

```bash
bin/rails igdb:match_yesterday
```

For Kamal, use the host script:

```bash
scripts/igdb_match_yesterday_production.sh
```

Install script + cron entry on production host:

```bash
bin/install-prod-igdb-cron
```

Defaults:
- schedule: `0 5 * * *`
- script path: `/home/ubuntu/sharenite/igdb_match_yesterday_production.sh`
- log path: `/home/ubuntu/backups/sharenite/igdb_match.log`

Optional overrides:
- `REMOTE_USER`
- `CRON_SCHEDULE`
- `REMOTE_SCRIPT_PATH`
- `REMOTE_LOG_PATH`
- first argument: explicit host override
