#!/bin/bash
set -o errexit
set -o nounset

IMG="$1"

DB_CONTAINER="elastic"
DATA_CONTAINER="${DB_CONTAINER}-data"

LICENSE_URL="http://localhost:9200/_xpack/license"

function cleanup {
  echo "Cleaning up"
  docker rm -f "$DB_CONTAINER" "$DATA_CONTAINER" >/dev/null 2>&1 || true
}

function wait_for_xpack {
  for _ in $(seq 1 240); do
    if docker exec -it "$DB_CONTAINER" curl -fs "$LICENSE_URL" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done

  echo "DB never came online"
  docker logs "$DB_CONTAINER"
  return 1
}

function get_license_uid {
  local doc
  doc="$(docker exec -it "$DB_CONTAINER" curl -fs "$LICENSE_URL")"
  echo "$doc" | python -c 'import sys, json; print(json.load(sys.stdin)["license"]["uid"])'
}

trap cleanup EXIT
cleanup

if [[ "$TAG" =~ ^1 ]] || [[ "$TAG" =~ ^2 ]]; then
  echo "Not running x-pack test on ${TAG}"
  exit 0
fi

echo "Creating data container"
docker create --name "$DATA_CONTAINER" "$IMG"

echo "Initializing DB"
docker run -it --rm \
  -e USERNAME=user -e PASSPHRASE=pass -e DATABASE=db \
  --volumes-from "$DATA_CONTAINER" \
  "$IMG" --initialize \
  >/dev/null 2>&1

echo "Starting DB with X-Pack"
docker run -d --name="$DB_CONTAINER" \
  -e EXPOSE_HOST=127.0.0.1 -e EXPOSE_PORT_27217=27217 \
  -e ELASTICSEARCH_XPACK="1" \
  --volumes-from "$DATA_CONTAINER" \
  "$IMG"
wait_for_xpack

echo "Checking license"
uid="$(get_license_uid)"
echo "UID is: ${uid}"

echo "Restarting"
docker restart "$DB_CONTAINER"
wait_for_xpack

if [[ "$uid" != "$(get_license_uid)" ]]; then
  echo "License UID changed after restart"
  exit 1
fi

echo "Destroying"
docker stop "$DB_CONTAINER"
docker rm "$DB_CONTAINER"

echo "Recreating"
docker run -d --name="$DB_CONTAINER" \
  -e EXPOSE_HOST=127.0.0.1 -e EXPOSE_PORT_27217=27217 \
  -e ELASTICSEARCH_XPACK="1" \
  --volumes-from "$DATA_CONTAINER" \
  "$IMG"
wait_for_xpack

if [[ "$uid" != "$(get_license_uid)" ]]; then
  echo "License UID changed after recreate"
  exit 1
fi

if [[ ! "$TAG" =~ ^5 ]]; then
  echo "Checking keystore was not used"
  ! docker exec -it "$DB_CONTAINER" /elasticsearch/bin/elasticsearch-keystore list | grep -v keystore.seed
fi
