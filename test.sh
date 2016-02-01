#!/bin/bash
set -o errexit
set -o nounset
set -o xtrace


VERSION="1.5"
IMG="quay.io/aptible/elasticsearch:$VERSION"

DATA="/tmp/docker-elasticsearch/data"

# TODO - Be more dynamic
DOCKER_VM_HOST="192.168.99.100"

ES_USERNAME="test"
ES_PASSPHRASE="testpass"


ES_A_CONTAINER="es-a"
ES_A_HTTPS_PORT=4431
ES_A_TRANSPORT_PORT=19301
ES_A_URL="https://$ES_USERNAME:$ES_PASSPHRASE@$DOCKER_VM_HOST:$ES_A_HTTPS_PORT/"

ES_B_CONTAINER="es-b"
ES_B_HTTPS_PORT=4432
ES_B_TRANSPORT_PORT=19302
ES_B_URL="https://$ES_USERNAME:$ES_PASSPHRASE@$DOCKER_VM_HOST:$ES_B_HTTPS_PORT/"

ES_HTTPS_PORT=443
ES_TRANSPORT_PORT=9300


# Cleanup
docker rm -f "$ES_A_CONTAINER" "$ES_B_CONTAINER" || true
docker-machine ssh docker-vm sudo rm -rf "${DATA}"

# Image
make 1.5


echo "Initializing ${ES_A_CONTAINER}"
docker run -it --rm \
  -v "${DATA}/${ES_A_CONTAINER}:/var/db" \
  -e USERNAME="$ES_USERNAME" -e PASSPHRASE="$ES_PASSPHRASE" \
  "$IMG" --initialize


echo "Running ${ES_A_CONTAINER}"
docker run -d --name "$ES_A_CONTAINER" \
  -p "$ES_A_HTTPS_PORT:$ES_HTTPS_PORT" -p "$ES_A_TRANSPORT_PORT:$ES_TRANSPORT_PORT" \
  -v "${DATA}/$ES_A_CONTAINER:/var/db" \
  -e PUBLISH_HOST="$DOCKER_VM_HOST" -e PUBLISH_PORT_9300="$ES_A_TRANSPORT_PORT" \
  "${IMG}"


echo "Waiting for ${ES_A_CONTAINER} to come online"
until curl --insecure --silent --fail > /dev/null "$ES_A_URL"; do sleep 0.5; done


echo "Initializing ${ES_B_CONTAINER} (from ${ES_A_CONTAINER})"
docker run -it --rm \
  -v "${DATA}/$ES_B_CONTAINER:/var/db" \
  -e USERNAME="$ES_USERNAME" -e PASSPHRASE="$ES_PASSPHRASE" \
  "$IMG" --initialize-from "$ES_A_URL"


echo "Running ${ES_B_CONTAINER}"
docker run -d --name "$ES_B_CONTAINER" \
  -p "$ES_B_HTTPS_PORT:$ES_HTTPS_PORT" -p "$ES_B_TRANSPORT_PORT:$ES_TRANSPORT_PORT" \
  -v "${DATA}/$ES_B_CONTAINER:/var/db" \
  -e PUBLISH_HOST="$DOCKER_VM_HOST" -e PUBLISH_PORT_9300="$ES_B_TRANSPORT_PORT" \
  "$IMG"


echo "Waiting for ${ES_B_CONTAINER} to come online"
until curl --insecure --silent --fail > /dev/null "$ES_B_URL"; do sleep 0.5; done


echo "Running tests on ${ES_A_CONTAINER}, ${ES_B_CONTAINER}"
curl --silent --insecure "${ES_A_URL}/_cluster/health" | python -c 'import json, sys; assert json.load(sys.stdin)["number_of_nodes"] == 2'


# Create some data on ES-A!
curl --insecure --fail -XPUT "${ES_A_URL}customer/?pretty=true"
curl --insecure --fail -XPUT "${ES_A_URL}/customer/external/1?pretty=true" -d '{
  "name": "John Doe"
}'

# Check out the data on ES-B!
curl --silent --insecure --fail -XGET "${ES_B_URL}/customer/external/1?pretty"


echo "Test OK!"
