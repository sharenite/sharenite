SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
docker compose -p sharenite-production -f $SCRIPT_DIR/docker-compose-prod.yml build --no-cache