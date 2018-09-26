#!/usr/bin/env bats

@test "It should have the repository-s3 plugin installed" {
  /elasticsearch/bin/elasticsearch-plugin list | grep -q "repository-s3"
}
