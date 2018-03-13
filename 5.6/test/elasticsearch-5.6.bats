#!/usr/bin/env bats

@test "It should install Elasticsearch 5.6.8" {
  run elasticsearch-wrapper --version
  [[ "$output" =~ "Version: 5.6.8"  ]]
}

@test "It should have the repository-s3 plugin installed" {
  /elasticsearch/bin/elasticsearch-plugin list | grep -q "repository-s3"
}
