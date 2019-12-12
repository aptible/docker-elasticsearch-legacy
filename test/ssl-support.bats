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

@test "All versions are configured to support SSLv3, TLS 1, 1.1, and 1.2." {
  start_elasticsearch

  # This cannot be direcly tested as above on Ubuntu 16,
  # as SSLv3 has been removed from OpenSSL entirely in that version
  grep "ssl_protocols SSLv3 TLSv1 TLSv1.1 TLSv1.2;" /etc/nginx/nginx.conf
}
