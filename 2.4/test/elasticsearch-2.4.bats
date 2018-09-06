#!/usr/bin/env bats

@test "It should have the cloud-aws plugin installed" {
  /elasticsearch/bin/plugin list | grep -q "cloud-aws"
}
