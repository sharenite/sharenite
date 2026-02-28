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
