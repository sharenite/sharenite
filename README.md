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
3. post-deploy checks (`db:abort_if_pending_migrations`, schema contract checks, and recent 500/schema error scan)

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
