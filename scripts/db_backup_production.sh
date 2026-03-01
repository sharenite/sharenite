#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-$HOME/backups/sharenite}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
DB_NAME="${DB_NAME:-sharenite_production}"
DB_USER="${DB_USER:-sharenite}"
SERVICE="${SERVICE:-sharenite}"

mkdir -p "$BACKUP_DIR"

# Prevent overlapping backup runs.
exec 9>"$BACKUP_DIR/.backup.lock"
flock -n 9 || exit 0

timestamp="$(date +'%Y-%m-%d_%H_%M_%S')"
output_file="$BACKUP_DIR/prod_dump_${timestamp}.sql.gz"

db_container="$(docker ps --filter "label=service=${SERVICE}-db" --format '{{.Names}}' | head -n1)"
if [[ -z "$db_container" ]]; then
  echo "No running container found for label service=${SERVICE}-db" >&2
  exit 1
fi

docker exec "$db_container" pg_dump \
  -U "$DB_USER" \
  -d "$DB_NAME" \
  --clean \
  --if-exists \
  | gzip -9 > "$output_file"

find "$BACKUP_DIR" -type f -name 'prod_dump_*.sql.gz' -mtime "+$RETENTION_DAYS" -delete
