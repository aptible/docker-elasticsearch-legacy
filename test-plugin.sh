#!/bin/bash
set -o errexit
set -o nounset

IMG="$1"

DB_CONTAINER="elastic"
DATA_CONTAINER="${DB_CONTAINER}-data"

PLUGINS="ingest-attachment analysis-phonetic"

function cleanup {
  echo "Cleaning up"
  docker rm -f "$DB_CONTAINER" "$DATA_CONTAINER" >/dev/null 2>&1 || true
}

function wait_for_plugin {

  for _ in $(seq 1 60); do
    if docker exec $DB_CONTAINER /elasticsearch/bin/elasticsearch-plugin list | grep "$1"; then
      return 0
    fi
    sleep 1
  done

  echo "${1} did not get installed"
  docker logs "$DB_CONTAINER"
  return 1
}

if dpkg --compare-versions "$ES_VERSION" lt 2; then
  echo "Not running plug test on ES <2"
  exit 0
fi

trap cleanup EXIT
cleanup

echo "Creating data container"
docker create --name "$DATA_CONTAINER" "$IMG"

echo "Initializing DB"
docker run -it --rm \
  -e USERNAME=aptible -e PASSPHRASE=password -e DATABASE=db \
  --volumes-from "$DATA_CONTAINER" \
  "$IMG" --initialize \
  >/dev/null 2>&1

echo "Starting DB with plugin"
docker run -d --name="$DB_CONTAINER" \
  --volumes-from "$DATA_CONTAINER" \
  -e ES_PLUGINS="$PLUGINS"  \
  "$IMG"

for PLUGIN in $PLUGINS; do
  wait_for_plugin "$PLUGIN"
done