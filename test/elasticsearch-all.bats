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

@test "It should have a unique cluster name (based on host name)." {
  # This can be used as a unique identifier in monitoring, such as in Telegraph
  # see https://aptible.zendesk.com/agent/tickets/24449

  # It also is used as a key for defining a cluster, so in the future any
  # additional cluster nodes will need it set to this value, too.

  SETTINGS_PATH='_cluster/settings?include_defaults=true&flat_settings=true&pretty=true'
  CLUSTER_NAME_SETTING='"cluster.name" : "foo.bar"'

  EXPOSE_HOST="foo.bar" start_elasticsearch

  curl -k --fail "https://aptible:password@localhost:9200/${SETTINGS_PATH}" | grep "${CLUSTER_NAME_SETTING}"
}

export_exposed_ports() {
  ES_PORT_VAR="EXPOSE_PORT_$ES_PORT"
  export $ES_PORT_VAR=$ES_PORT
}

@test "It should return valid JSON for --discover and --connection-url" {
  EXPOSE_HOST=localhost PASSPHRASE="password" \
    run-database.sh --connection-url | python -c 'import sys, json; json.load(sys.stdin)'

  EXPOSE_HOST=localhost PASSPHRASE="password" \
    run-database.sh --discover | python -c 'import sys, json; json.load(sys.stdin)'
}

@test "It should return a usable connection URL for --connection-url" {
  start_elasticsearch
  export_exposed_ports

  EXPOSE_HOST=localhost PASSPHRASE="password" \
    run-database.sh --connection-url > "${TEST_BASE_DIRECTORY}/url"

  pushd "${TEST_BASE_DIRECTORY}"
  URL="$(python -c "import sys, json; print json.load(open('url'))['credentials'][0]['connection_url']")"
  popd

  [[ "https://aptible:password@localhost:443" = "$URL" ]]

  run curl -k --fail "$URL"
}

