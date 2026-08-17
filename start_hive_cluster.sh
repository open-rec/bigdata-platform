#!/usr/bin/env bash
# Start the hive component and everything it needs.
# Starts: HDFS + YARN + the metastore database, metastore and HiveServer2.
#
# A shim over platform.sh so the dependency closure stays defined in one place.
# Runs in the background; follow the output with `./platform.sh logs`.
exec "$(dirname "$0")/platform.sh" up hive "$@"
