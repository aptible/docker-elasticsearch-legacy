#!/usr/bin/env python
import sys
import json
import re


def main():
    cluster_info = json.load(sys.stdin)
    print "CLUSTER_NAME='{0}'".format(cluster_info["cluster_name"])

    node_addresses = []
    for node in cluster_info["nodes"].values():
        m = re.match(r"inet\[/(.+)\]", node["transport_address"])
        node_addresses.append(m.group(1))

    print "CLUSTER_HOSTS='{0}'".format(','.join(node_addresses))


if __name__ == "__main__":
    # Expect to be passed the (JSON) output of http://.../_nodes
    main()
