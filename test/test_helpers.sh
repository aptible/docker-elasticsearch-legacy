#!/bin/bash

initialize_elasticsearch() {
  USERNAME=aptible PASSPHRASE=password run-database.sh --initialize
}

wait_for_elasticsearch() {
  # We pass the ES_PID via a global variable because we can't rely on
  # $(wait_for_elasticsearch) as it would result in orpahning the ES process
  # (which makes us unable to `wait` it).
  run-database.sh "$@" >> "$ES_LOG" 2>&1 &
  ES_PID="$!"
  for _ in $(seq 1 60); do
    if grep -q "started" "$ES_LOG" 2>/dev/null; then
      return 0
    fi
    sleep 1
  done
  echo "Database timed out"
  return 1
}

start_elasticsearch() {
  initialize_elasticsearch
  wait_for_elasticsearch
}

setup() {
  export OLD_DATA_DIRECTORY="$DATA_DIRECTORY"
  export OLD_SSL_DIRECTORY="$SSL_DIRECTORY"
  export DATA_DIRECTORY=/tmp/datadir
  export SSL_DIRECTORY=/tmp/ssldir
  export ES_LOG="$BATS_TEST_DIRNAME/elasticsearch.log"
  rm -rf "$DATA_DIRECTORY"
  rm -rf "$SSL_DIRECTORY"
  mkdir -p "$DATA_DIRECTORY"
  mkdir -p "$SSL_DIRECTORY"
}

shutdown_elasticsearch() {
  JAVA_PID=$(pgrep java) || return 0
  run pkill java
  while [ -n "$JAVA_PID" ] && [ -e "/proc/${JAVA_PID}" ]; do sleep 0.1; done
}

teardown() {
  shutdown_elasticsearch
  export DATA_DIRECTORY="$OLD_DATA_DIRECTORY"
  export SSL_DIRECTORY="$OLD_SSL_DIRECTORY"
  unset OLD_DATA_DIRECTORY
  unset OLD_SSL_DIRECTORY
  echo "---- BEGIN LOGS ----"
  cat "$ES_LOG" || true
  echo "---- END LOGS ----"
  rm -f "$ES_LOG"
}
