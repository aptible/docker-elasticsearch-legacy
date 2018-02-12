#!/usr/bin/env bats

@test "It should install Elasticsearch 5.1.1" {
  run elasticsearch-wrapper --version
  [[ "$output" =~ "Version: 5.1.1"  ]]
}

@test "It should have the repository-s3 plugin installed" {
  /elasticsearch/bin/elasticsearch-plugin list | grep -q "repository-s3"
}
