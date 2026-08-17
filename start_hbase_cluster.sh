#!/usr/bin/env bash
# Start the hbase component and everything it needs.
# Starts: ZooKeeper + HDFS + the HBase master, 2 regionservers and Thrift gateway.
#
# A shim over platform.sh so the dependency closure stays defined in one place.
# Runs in the background; follow the output with `./platform.sh logs`.
exec "$(dirname "$0")/platform.sh" up hbase "$@"
