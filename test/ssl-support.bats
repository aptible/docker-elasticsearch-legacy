#!/usr/bin/env bats

source "${BATS_TEST_DIRNAME}/test_helpers.sh"

local_s_client() {
  openssl s_client -connect localhost:9200 "$@" < /dev/null
}

@test "It should allow connections using TLS1.2" {
  start_elasticsearch

  local_s_client -tls1_2
}

@test "It should allow connections using TLS1.1" {
  start_elasticsearch

  local_s_client -tls1_1
}

@test "It should not allow connections using TLS1.0" {
  start_elasticsearch

  ! local_s_client -tls1
}

@test "It should not allow connections using SSLv3" {
  # This cannot be direcly tested as above on Ubuntu 16, as
  # SSLv3 has been removed from OpenSSL entirely in that version
  # We'll have to take Elastic's word that the setting we specified
  # for `ssl.supported_protocols` disables it.
}
