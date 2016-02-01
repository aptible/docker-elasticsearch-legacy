#!/bin/bash
set -o errexit
set -o nounset
set -o xtrace


VERSION="1.5"
IMG="quay.io/aptible/elasticsearch:$VERSION"

DATA="/tmp/docker-elasticsearch/data"

ES_A_CONTAINER="es-a"
ES_A_HTTPS_PORT=4431
ES_A_TRANSPORT_PORT=19301

ES_B_CONTAINER="es-b"
ES_B_HTTPS_PORT=4432
ES_B_TRANSPORT_PORT=19302

ES_HTTPS_PORT=443
ES_TRANSPORT_PORT=9300

DOCKER_VM_HOST="192.168.99.100"  # TODO - Be more dynamic


USERNAME="test"
PASSPHRASE="testpass"



# Cleanup
docker rm -f "$ES_A_CONTAINER" "$ES_B_CONTAINER" || true
docker-machine ssh docker-vm sudo rm -rf "${DATA}"

# Image
make 1.5


echo "Running ${ES_A_CONTAINER}"
docker run -d --name "$ES_A_CONTAINER" \
  -p "$ES_A_HTTPS_PORT:$ES_HTTPS_PORT" -p "$ES_A_TRANSPORT_PORT:$ES_TRANSPORT_PORT" \
  -e NODE_PUBLISH_HOST="$DOCKER_VM_HOST" -e NODE_PUBLISH_PORT="$ES_A_TRANSPORT_PORT" \
  -e USERNAME="$USERNAME" -e PASSPHRASE="$PASSPHRASE" \
  --entrypoint bash \
  -v "${DATA}/$ES_A_CONTAINER:/var/db" \
  "${IMG}" \
  -c "run-database.sh --initialize && run-database.sh"


echo "Waiting for ${ES_A_CONTAINER} to come online"
until curl --insecure --silent --fail > /dev/null "https://$USERNAME:$PASSPHRASE@$DOCKER_VM_HOST:$ES_A_HTTPS_PORT"; do sleep 0.5; done


echo "Extracting init data from ${ES_A_CONTAINER}"
eval "$(docker run -it -v "${DATA}/${ES_A_CONTAINER}:/var/db" --rm "$IMG" --activate-leader | dos2unix)"


echo "Running ${ES_B_CONTAINER} (from ${ES_A_CONTAINER})"
docker run -d --name "$ES_B_CONTAINER" \
  -p "$ES_B_HTTPS_PORT:$ES_HTTPS_PORT" -p "$ES_B_TRANSPORT_PORT:$ES_TRANSPORT_PORT" \
  -e NODE_PUBLISH_HOST="$DOCKER_VM_HOST" -e NODE_PUBLISH_PORT="$ES_B_TRANSPORT_PORT" \
  -e "ELASTIC_REPLICATION_HTACCESS=$ELASTIC_REPLICATION_HTACCESS" \
  --entrypoint bash \
  -v "${DATA}/$ES_A_CONTAINER:/var/db" \
  "$IMG" \
  -c "run-database.sh --initialize-from https://$USERNAME:$PASSPHRASE@$DOCKER_VM_HOST:$ES_A_HTTPS_PORT/ && run-database.sh"


echo "Waiting for ${ES_B_CONTAINER} to come online"
until curl --insecure --silent --fail > /dev/null "https://$USERNAME:$PASSPHRASE@$DOCKER_VM_HOST:$ES_B_HTTPS_PORT"; do sleep 0.5; done


echo "Running tests on ${ES_A_CONTAINER}, ${ES_B_CONTAINER}"

