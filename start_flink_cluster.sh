#!/usr/bin/env bash
# Start the Flink component and everything it needs.
# Starts: HDFS + one JobManager and two TaskManagers.
exec "$(dirname "$0")/platform.sh" up flink "$@"
