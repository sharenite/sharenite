#!/usr/bin/env bash
set -euo pipefail

DESTINATION="${DESTINATION:-production}"
SERVICE="${SERVICE:-sharenite}"
ROLE="${ROLE:-web}"

web_container="$(docker ps \
  --filter "label=service=${SERVICE}" \
  --filter "label=destination=${DESTINATION}" \
  --filter "label=role=${ROLE}" \
  --filter "status=running" \
  --format '{{.Names}}' | head -n1)"

if [[ -z "$web_container" ]]; then
  echo "No running web container found for service=${SERVICE} destination=${DESTINATION}" >&2
  exit 1
fi

docker exec "$web_container" bin/rails igdb:match_yesterday
