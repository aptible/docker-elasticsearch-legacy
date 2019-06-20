#!/usr/bin/env bats

source "${BATS_TEST_DIRNAME}/test_helpers.sh"

@test "It should have the repository-s3 plugin installed" {
  /elasticsearch/bin/elasticsearch-plugin list | grep -q "repository-s3"
}

@test "It should install Elasticsearch $ES_VERSION" {
  /elasticsearch/bin/elasticsearch --version | grep $ES_VERSION
}

@test "It should not expose Elasticsearch over HTTP" {
  start_elasticsearch
  ! curl -fail http://aptible:password@localhost:9200
}

@test "It should expose Elasticsearch over HTTPS with Basic Auth" {
  start_elasticsearch
  run curl -k https://aptible:password@localhost:9200
  [[ "$output" =~ "tagline"  ]]
}

@test "It should allow the SSL certificate and key to be configured via ENV at --initialize" {
  # This tests both that we accept a cert at --initialize, and use a cert from
  # the filesystem at runtime
  mkdir /tmp/cert
  openssl req -x509 -batch -nodes -newkey rsa:2048 -keyout /tmp/cert/server.key \
    -out /tmp/cert/server.crt -subj /CN=elasticsearch-bats-test.com

  SSL_CERTIFICATE="$(cat /tmp/cert/server.crt)" SSL_KEY="$(cat /tmp/cert/server.key)" initialize_elasticsearch
  wait_for_elasticsearch

  curl -kv https://localhost:9200 2>&1 | grep "CN=elasticsearch-bats-test.com"
  rm -rf /tmp/cert
}

@test "It should allow the SSL certificate and key to be configured via ENV at runtime" {
  mkdir /tmp/cert
  openssl req -x509 -batch -nodes -newkey rsa:2048 -keyout /tmp/cert/server.key \
    -out /tmp/cert/server.crt -subj /CN=elasticsearch-bats-test.com

  initialize_elasticsearch
  SSL_CERTIFICATE="$(cat /tmp/cert/server.crt)" SSL_KEY="$(cat /tmp/cert/server.key)" wait_for_elasticsearch

  curl -kv https://localhost:9200 2>&1 | grep "CN=elasticsearch-bats-test.com"
  rm -rf /tmp/cert
}

@test "It should reject unauthenticated requests with Basic Auth enabled over HTTPS" {
  start_elasticsearch
  run curl -k --fail https://localhost:9200
  [[ "$status" -eq 22 ]]  # CURLE_HTTP_RETURNED_ERROR - https://curl.haxx.se/libcurl/c/libcurl-errors.html
  [[ "$output" =~ "401 Unauthorized"  ]]
}

@test "It should not send multicast discovery ping requests" {
  initialize_elasticsearch
  run timeout 5 elasticsearch-wrapper -Des.logger.discovery=TRACE
  ! [[ "$output" =~ "sending ping request" ]]
  ! [[ "$output" =~ "multicast" ]]
}

@test "It should exit when ES exits (or is killed) and report the exit code" {
  start_elasticsearch

  # Check that our PID is valid
  run ps af --pid "$ES_PID"
  [[ "$output" =~ "$ES_PID" ]]

  # Check that Java is a child
  run ps --ppid "$ES_PID"
  [[ "$output" =~ "java" ]]

  # Kill ES (emulate a OOM process kill)
  kill -KILL "$ES_PID"

  # Check that we exited with ES's status code
  wait "$ES_PID" || exit_code="$?"
  [[ "$exit_code" -eq "$((128+9))" ]]
}

@test "It should support ES_HEAP_SIZE=256m" {
  initialize_elasticsearch
  ES_HEAP_SIZE=256m wait_for_elasticsearch
  run ps auxwww
  [[ "$output" =~ "-Xms256m -Xmx256m" ]]
}

@test "It should support ES_HEAP_SIZE=512m" {
  initialize_elasticsearch
  ES_HEAP_SIZE=512m wait_for_elasticsearch
  run ps auxwww
  [[ "$output" =~ "-Xms512m -Xmx512m" ]]
}

@test "It should autoconfigure ES_HEAP_SIZE based on APTIBLE_CONTAINER_SIZE" {
  initialize_elasticsearch
  APTIBLE_CONTAINER_SIZE=1024 wait_for_elasticsearch
  run ps auxwww
  [[ "$output" =~ "-Xms512m -Xmx512m" ]]
}

@test "It should not do cluster discovery." {
  # This will need to be carefully configured later to support clustering.

  SETTINGS_PATH='_cluster/settings?include_defaults=true&flat_settings=true&pretty=true'
  DISCOVERY_SETTING='"discovery.type" : "single-node"'

  start_elasticsearch

  curl -k --fail "https://aptible:password@localhost:9200/${SETTINGS_PATH}" | grep "${DISCOVERY_SETTING}"
}
