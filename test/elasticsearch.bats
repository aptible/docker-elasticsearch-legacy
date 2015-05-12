#!/usr/bin/env bats

@test "It should install Elasticsearch 1.3.2" {
  run /elasticsearch/bin/elasticsearch -v
  [[ "$output" =~ "Version: 1.3.2"  ]]
}

wait_for_elasticsearch() {
  /usr/sbin/nginx-wrapper > $BATS_TEST_DIRNAME/nginx.log &
  while  ! grep "started" $BATS_TEST_DIRNAME/nginx.log ; do sleep 0.1; done
}

teardown() {
  PID=$(pgrep java)
  pkill java
  pkill nginx
  while [ -n "$PID" ] && [ -e /proc/$PID ]; do sleep 0.1; done
}

@test "It should provide an HTTP wrapper" {
  wait_for_elasticsearch
  run wget -qO- http://localhost > /test-output
  run wget -qO- http://localhost
  [[ "$output" =~ "tagline"  ]]
}

@test "It should provide an HTTPS wrapper" {
  skip
  wait_for_elasticsearch
  run wget -qO- --no-check-certificate https://localhost
  [[ "$output" =~ "tagline"  ]]
}

@test "It should allow for HTTP Basic Auth configuration via ENV" {
  export USERNAME=aptible
  export PASSWORD=password
  wait_for_elasticsearch
  run wget -qO- http://aptible:password@localhost
  [[ "$output" =~ "tagline"  ]]
}

@test "It should reject unauthenticated requests with Basic Auth enabled" {
  export USERNAME=aptible
  export PASSWORD=password
  wait_for_elasticsearch
  run wget -qO- http://localhost
  [ "$status" -ne "0" ]
  ! [[ "$output" =~ "tagline"  ]]
}

@test "It should disable multicast cluster discovery in config" {
  run grep "discovery.zen.ping.multicast.enabled" elasticsearch/config/elasticsearch.yml
  [[ "$output" =~ "false" ]]
}

@test "It should not send multicast discover ping requests" {
  run timeout 5 /elasticsearch/bin/elasticsearch -Des.logger.discovery=TRACE
  ! [[ "$output" =~ "sending ping request" ]]
}
