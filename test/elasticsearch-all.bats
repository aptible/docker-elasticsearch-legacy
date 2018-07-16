#!/usr/bin/env bats

source "${BATS_TEST_DIRNAME}/test_helpers.sh"

@test "It should provide an HTTP wrapper" {
  initialize_elasticsearch
  rm "$DATA_DIRECTORY/auth_basic.htpasswd"  # Disable auth for this test
  wait_for_elasticsearch
  run curl  http://localhost > "${BATS_TEST_DIRNAME}/test-output"
  run curl http://localhost
  [[ "$output" =~ "tagline"  ]]
}

@test "It should expose Elasticsearch over HTTP with Basic Auth" {
  start_elasticsearch
  run curl http://aptible:password@localhost
  [[ "$output" =~ "tagline"  ]]
}

@test "It should expose Elasticsearch over HTTPS with Basic Auth" {
  start_elasticsearch
  run curl -k https://aptible:password@localhost
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

  curl -kv https://localhost 2>&1 | grep "CN=elasticsearch-bats-test.com"
  rm -rf /tmp/cert
}

@test "It should allow the SSL certificate and key to be configured via ENV at runtime" {
  mkdir /tmp/cert
  openssl req -x509 -batch -nodes -newkey rsa:2048 -keyout /tmp/cert/server.key \
    -out /tmp/cert/server.crt -subj /CN=elasticsearch-bats-test.com

  initialize_elasticsearch
  SSL_CERTIFICATE="$(cat /tmp/cert/server.crt)" SSL_KEY="$(cat /tmp/cert/server.key)" wait_for_elasticsearch

  curl -kv https://localhost 2>&1 | grep "CN=elasticsearch-bats-test.com"
  rm -rf /tmp/cert
}

@test "It should reject unauthenticated requests with Basic Auth enabled over HTTP" {
  start_elasticsearch
  run curl --fail http://localhost
  [[ "$status" -eq 22 ]]  # CURLE_HTTP_RETURNED_ERROR - https://curl.haxx.se/libcurl/c/libcurl-errors.html
  [[ "$output" =~ "401 Unauthorized"  ]]
}

@test "It should reject unauthenticated requests with Basic Auth enabled over HTTPS" {
  start_elasticsearch
  run curl -k --fail https://localhost
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

  # Check that Java and Nginx are children
  run ps --ppid "$ES_PID"
  [[ "$output" =~ "nginx" ]]
  [[ "$output" =~ "java" ]]

  # Kill ES (emulate a OOM process kill)
  kill -KILL "$ES_PID"

  # Check that we exited with ES's status code
  wait "$ES_PID" || exit_code="$?"
  [[ "$exit_code" -eq "$((128+9))" ]]
}

@test "It should support --readonly mode" {
  initialize_elasticsearch
  wait_for_elasticsearch "--readonly"

  curl "http://aptible:password@localhost"

  run curl --fail -XPOST "http://aptible:password@localhost"
  [[ "$output" =~ "Forbidden" ]]
  [[ "$status" -eq 22 ]]  # CURLE_HTTP_RETURNED_ERROR - https://curl.haxx.se/libcurl/c/libcurl-errors.html
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

@test "It should disable multicast cluster discovery in config" {
  if dpkg --compare-versions "$ES_VERSION" ge 5; then
    skip "Not needed on ${ES_VERSION}"
  fi

  initialize_elasticsearch
  run grep "discovery.zen.ping.multicast.enabled" /elasticsearch/config/elasticsearch.yml
  [[ "$output" =~ "false" ]]
}
