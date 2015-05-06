#!/usr/bin/env bats

@test "It should install Elasticsearch 1.5.2" {
  run /elasticsearch/bin/elasticsearch -v
  [[ "$output" =~ "Version: 1.5.2"  ]]
}

wait_for_elasticsearch() {
  /usr/sbin/nginx-wrapper > $BATS_TEST_DIRNAME/nginx.log &
  while  ! grep "started" $BATS_TEST_DIRNAME/nginx.log ; do sleep 0.1; done
}

teardown() {
  PID=$(pgrep java) || return 0
  run pkill java
  run pkill nginx
  while [ -n "$PID" ] && [ -e /proc/$PID ]; do sleep 0.1; done
  true
}

@test "It should provide an HTTP wrapper" {
  wait_for_elasticsearch
  run wget -qO- http://localhost > /test-output
  run wget -qO- http://localhost
  [[ "$output" =~ "tagline"  ]]
}

@test "It should provide an HTTPS wrapper" {
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
