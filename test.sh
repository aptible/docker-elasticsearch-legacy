#!/bin/bash
set -o errexit
set -o nounset

IMG="$REGISTRY/$REPOSITORY:$TAG"

echo "Unit Tests..."
docker run -it --rm --entrypoint "bash" "$IMG" \
 -c "bats /tmp/test"

TESTS=(
  test-restart
  test-exit-code
  test-xpack
  test-plugin
 )

for t in "${TESTS[@]}"; do
  echo "--- START ${t} ---"
  "./${t}.sh" "$IMG"
  echo "--- OK    ${t} ---"
  echo
done

if [[ -n ${AWS_ACCESS_KEY_ID:-} ]]; then
  ./test-backup.sh "$IMG"
else
  echo "Skipping S3 backup test, no AWS_ACCESS_KEY_ID set."
fi

echo "#############"
echo "# Tests OK! #"
echo "#############"
