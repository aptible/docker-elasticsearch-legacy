#!/usr/bin/env bats

source "${BATS_TEST_DIRNAME}/test_helpers.sh"

local_s_client() {
  openssl s_client -connect localhost:443 "$@" < /dev/null
}

@test "It should allow connections using TLS1.2" {
  start_elasticsearch

  local_s_client -tls1_2
}

@test "It should allow connections using TLS1.1" {
  start_elasticsearch

  local_s_client -tls1_1
}

@test "It should allow connections using TLS1.0" {
  start_elasticsearch

  local_s_client -tls1
}

@test "Only 1.5 version allows connections using SSLv3" {
  start_elasticsearch

  if dpkg --compare-versions "$ES_VERSION" lt 2; then
    local_s_client -ssl3
  else
    # This test won't succeed in making a requests to the database at all on 
    # Ubuntu 16, as SSLv3 has been removed from OpenSSL entirely in that version
    ! local_s_client -ssl3
  fi
}
