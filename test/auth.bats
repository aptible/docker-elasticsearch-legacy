#!/usr/bin/env bats

source "${BATS_TEST_DIRNAME}/test_helpers.sh"

@test "It should keep the 'aptible' user in local storage, not the security index." {
  start_elasticsearch

  # This user will not be in the .security index:
  ! curl -k --fail "https://aptible:password@localhost:9200/_security/user/aptible"

  # This user should be found in the default (file) realm:
  APTIBLE_USER_REALM='"authentication_realm":{"name":"default_file","type":"file"}'
  curl -k --fail "https://aptible:password@localhost:9200/_security/_authenticate" | grep "${APTIBLE_USER_REALM}"
}

@test "It should not let you change the 'aptible' user password." {
  start_elasticsearch

  CONTENT_TYPE='Content-Type: application/json'
  RESULT='user must exist in order to change password'

  curl -k -X POST "https://aptible:password@localhost:9200/_security/user/aptible/_password" \
    -H 'Content-Type: application/json' -d'{"password" : "s3cr3t"}' | grep "${RESULT}"
}

@test "Customers can set the password for the default users." {
  skip "TODO"
  #elastic, kibana, logstash_system, beats_system, apm_system, remote_monitoring_user
}

@test "It should let us create a user via the API" {
  start_elasticsearch

  curl -k --fail -X POST "https://aptible:password@localhost:9200/_security/user/jacknich" \
   -H 'Content-Type: application/json' \
   -d '{ "password" : "jarV1s", "roles" : [ "admin", "other_role1" ] }'
  curl -k --fail "https://aptible:password@localhost:9200/_security/user/jacknich"
}
