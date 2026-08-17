#!/usr/bin/env bash
# Start the zookeeper component and everything it needs.
# Starts: the 3-node ZooKeeper ensemble.
#
# A shim over platform.sh so the dependency closure stays defined in one place.
# Runs in the background; follow the output with `./platform.sh logs`.
exec "$(dirname "$0")/platform.sh" up zookeeper "$@"
