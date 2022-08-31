SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
docker compose -p sharenite-nginx -f $SCRIPT_DIR/docker-compose-nginx.yml up -d
