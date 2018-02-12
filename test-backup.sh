#!/bin/bash
set -o errexit
set -o nounset

IMG="$1"

DB_CONTAINER="elastic"
DATA_CONTAINER="${DB_CONTAINER}-data"

S3_BUCKET="${S3_BUCKET:-aptible-unit-tests}"
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"
S3_REGION="${S3_REGION:-us-east-1}"
S3_BUCKET_BASE_PATH="${S3_BUCKET_BASE_PATH:-}"

REPOSITORY_URL="http://user:pass@localhost:9200/_snapshot/logstash_snapshots"

json=$(cat << EOF
{
  "type": "s3",
  "settings": {
    "bucket" : "${S3_BUCKET}",
    "base_path": "${S3_BUCKET_BASE_PATH}",
    "access_key": "${AWS_ACCESS_KEY_ID}",
    "secret_key": "${AWS_SECRET_ACCESS_KEY}",
    "protocol": "https",
    "server_side_encryption": true
  }
}
EOF
)

function cleanup {
  echo "Cleaning up"
  docker rm -f "$DB_CONTAINER" "$DATA_CONTAINER" >/dev/null 2>&1 || true
}

function wait_for_s3 {

  for _ in $(seq 1 30); do
    if docker exec "$DB_CONTAINER" curl -w "\n" -H'Content-Type: application/json' -sS -XPUT "${REPOSITORY_URL}" -d "$json" | grep '{\"acknowledged\":true}'; then
      echo "S3 backup succeeded."
      return 0
    fi
    sleep 1
  done

  echo "S3 plugin did not work"
  docker logs "$DB_CONTAINER"
  return 1
}

trap cleanup EXIT
cleanup

echo "Creating data container"
docker create --name "$DATA_CONTAINER" "$IMG"

echo "Initializing DB"
docker run -it --rm \
  -e USERNAME=user -e PASSPHRASE=pass -e DATABASE=db \
  --volumes-from "$DATA_CONTAINER" \
  "$IMG" --initialize \
  >/dev/null 2>&1

echo "Starting DB"
docker run -d --name="$DB_CONTAINER" \
  -e EXPOSE_HOST=127.0.0.1 -e EXPOSE_PORT_27217=27217 \
  --volumes-from "$DATA_CONTAINER" \
  "$IMG"

wait_for_s3
