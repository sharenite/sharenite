SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
docker compose -p sharenite-staging -f $SCRIPT_DIR/docker-compose-stag.yml build --no-cache