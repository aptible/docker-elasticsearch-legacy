#!/usr/bin/env bats

@test "It should install Elasticsearch 5.0.2" {
  run elasticsearch-wrapper --version
  [[ "$output" =~ "Version: 5.0.2"  ]]
}

@test "It should have the repository-s3 plugin installed" {
  /elasticsearch/bin/elasticsearch-plugin list | grep -q "repository-s3"
}
