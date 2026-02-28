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
export POSTGRES_PASSWORD='...'
export SHARENITE_DATABASE_PASSWORD='...'
export KARAFKA_PRO_LICENSE_ID='...'
export BUNDLE_GEMS__KARAFKA__IO='...'
EOF
direnv allow
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
export POSTGRES_PASSWORD=...
export SHARENITE_DATABASE_PASSWORD=...
export BUNDLE_GEMS__KARAFKA__IO=...
export KARAFKA_PRO_LICENSE_ID=...
export KARAFKA_UI_SECRET=...
export IGDB_CLIENT_ID=...
export IGDB_CLIENT_SECRET=...
export RECAPTCHA_SITE_KEY=...
export RECAPTCHA_SECRET_KEY=...
```

Deploy flow:

```bash
bundle exec kamal setup -d staging
bundle exec kamal deploy -d staging
```

Useful commands:

```bash
bundle exec kamal app logs -d staging -f
bundle exec kamal app exec -d staging -i "bin/rails db:migrate"
bundle exec kamal app exec -d staging -i "bin/rails c"
```
