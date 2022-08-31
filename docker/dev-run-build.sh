SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
docker compose -p sharenite-development -f $SCRIPT_DIR/docker-compose-dev.yml up --build -V
