#!/usr/bin/env bash
# Start the hdfs component and everything it needs.
# Starts: the namenode, 2 datanodes and the HDFS directory bootstrap.
#
# A shim over platform.sh so the dependency closure stays defined in one place.
# Runs in the background; follow the output with `./platform.sh logs`.
exec "$(dirname "$0")/platform.sh" up hdfs "$@"
