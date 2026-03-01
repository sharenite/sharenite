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

Production config is in `config/deploy.yml` and currently targets:
- Host: `new.sharenite.link`
- Server: `ns3031997.ip-5-135-141.eu`

Prepare env file:

```bash
cp .envrc.production.example .envrc.production
```

Set production values in `.envrc.production`, then run:

```bash
echo "$DOCKERHUB_TOKEN" | docker login -u "$DOCKERHUB_USERNAME" --password-stdin
# then SSH to ns3031997.ip-5-135-141.eu and run the same docker login command there
bin/kamal-production setup
bin/kamal-production deploy
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

Defaults:
- backup dir: `~/backups`
- file pattern: `prod_dump_YYYY-MM-DD_HH_MM_SS.sql.gz`
- retention: 7 days

Example cron (daily 04:30 server time):

```cron
30 4 * * * /home/ubuntu/sharenite/scripts/db_backup_production.sh >> /home/ubuntu/backups/backup.log 2>&1
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
