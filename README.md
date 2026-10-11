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

For an existing Kafka container created before the persistent-volume change, follow
the Kafka migration below **before** running `docker compose up`.

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

## Infrastructure maintenance (2026-10-11)

Staging and local Compose pin these releases:

| Service | Staging | Local Compose | Production baseline (unchanged) |
| --- | --- | --- | --- |
| PostgreSQL | `15.19-bookworm` | `15.19-alpine` | 15.17, Debian 13 |
| Redis | `7.4.11-alpine` | `7.4.11-alpine` | 7.4.8 |
| Kafka | `4.3.1` | `4.3.1` | 3.7.0 |
| Kafka UI | Not deployed | `ghcr.io/kafbat/kafka-ui:v1.5.0` | Not deployed |

PostgreSQL 15 is supported until November 2027. Staging retains Debian 12 to avoid
combining the patch with a libc/collation change. Production's future patch target
is `postgres:15.19-trixie`. See the
[PostgreSQL versioning policy](https://www.postgresql.org/support/versioning/) and
[Redis 7.4 release notes](https://raw.githubusercontent.com/redis/redis/7.4/00-RELEASENOTES).
Production accessory configuration is deliberately unchanged until its own data
migration and maintenance window.

Staging Kafka uses `/home/xenor/sharenite-kafka/data` mounted at its existing
`/tmp/kraft-combined-logs` path. It is reachable only on the Docker `kamal` network;
there is no published host port. Compose mounts a named volume at the same path
and binds development service ports to `127.0.0.1`.

### Preserve existing Kafka data before recreating its container

Kafka's "logs" contain queued messages, consumer offsets, and cluster metadata.
The old 3.7.0 configuration wrote these to the container's writable layer; its
anonymous volume at `/var/lib/kafka/data` did not protect the active directory.
Production still has this configuration. Never reboot/recreate an old broker
until its stopped data directory has been backed up and restored to the new mount.

The 3.7.0 image also had [KAFKA-16473](https://issues.apache.org/jira/browse/KAFKA-16473):
it stored `Some(...)` around the configured cluster ID. Staging preserves that
actual ID in its configuration; do not rewrite `meta.properties` to remove it.
For an existing local broker, read `cluster.id` from
`docker exec sharenite-kafka cat /tmp/kraft-combined-logs/meta.properties` and set
`KAFKA_CLUSTER_ID` to that exact value in your local `.env` before migrating.
New local clusters can use the Compose default.

For an existing local Compose broker, stop `bin/dev` and any other Kafka writers,
then migrate the stopped broker's entire directory (including hidden files and
`meta.properties`):

```bash
docker compose stop -t 120 kafka
mkdir -p tmp/infra-backups
# Choose a fresh filename; never overwrite your only backup.
docker cp sharenite-kafka:/tmp/kraft-combined-logs/. - > tmp/infra-backups/kafka-before-persistence.tar
kafka_volume="$(docker compose config --format json | python3 -c 'import json,sys; print(json.load(sys.stdin)["volumes"]["sharenite_kafka_data"]["name"])')"
docker volume create "$kafka_volume"
docker run --rm -i --user 0 --entrypoint /bin/sh \
  --mount "type=volume,source=$kafka_volume,target=/restore" apache/kafka:4.3.1 \
  -ec 'test -z "$(ls -A /restore)"; tar xpf - -C /restore; test -f /restore/meta.properties; chown -R 1000:1000 /restore' \
  < tmp/infra-backups/kafka-before-persistence.tar
docker compose up -d
```

Keep the backup until topics, offsets, and application sync have been verified.
Do not use `docker compose down -v`; it removes persistent data volumes.

### Staging accessory rollout

Application deploys do not refresh existing accessories. Use a maintenance window
for this single-broker setup, then deploy with `bin/deploy-staging-safe`:

1. Pull the pinned images first. Record current image IDs and mounts in a private,
   timestamped `/home/xenor/sharenite-infra-backups/` directory. Dump PostgreSQL in
   custom format and verify a full restore in an isolated PostgreSQL 15.19 container.
2. Stop staging web and worker with `bin/kamal-staging app stop`. Take a final
   database dump, force a Redis `SAVE`, and copy its RDB snapshot. Redis holds sync
   payloads as well as cache state, so preserve its existing `/data` bind mount.
3. Stop Kafka cleanly (allow 120 seconds), archive the entire stopped
   `/tmp/kraft-combined-logs` directory, and verify its checksum. Restore one copy
   with UID/GID 1000 to the new host directory and another to an isolated rehearsal
   directory. Keep the archive untouched for rollback.
4. In an isolated Docker network, start the copied data on 3.7.0, verify topics and
   offsets, then restart that copy on 4.3.1. Verify producer/consumer behavior.
   The [Kafka upgrade guide](https://kafka.apache.org/43/getting-started/upgrade/)
   supports this KRaft upgrade path. Retain metadata version 3.7-IV4 initially;
   finalizing newer metadata is a separate operation that can prevent downgrade.
5. Once the rehearsal passes, run `bin/kamal-staging accessory reboot db`, `redis`,
   and `kafka` individually. Verify the new database/Redis versions and unchanged
   application row counts, Kafka topic IDs, partition offsets, and consumer commits.
6. Start the app with `bin/kamal-staging app start`, run a Karafka client round trip
   on a temporary topic, then run `bin/deploy-staging-safe` and HTTP/asset checks.

If a Kafka binary upgrade fails before accepting new writes, stop it and restore
3.7.0 using the untouched pre-upgrade archive in a fresh directory. Do not restore
an old snapshot after accepting writes without accounting for those newer messages.
PostgreSQL and Redis retain their original bind mounts. Backups and image IDs must
be kept until the staging rollout is accepted.

Production has daily compressed SQL backups, but a production restore has not yet
been rehearsed. Its Kafka persistence and published plaintext port 9092 still need
the same migration in a separately authorized production rollout.

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
