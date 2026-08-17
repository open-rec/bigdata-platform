#!/usr/bin/env bash
# Start the spark component and everything it needs.
# Starts: HDFS + the Spark master, workers, history server and JupyterLab.
#
# A shim over platform.sh so the dependency closure stays defined in one place.
# Runs in the background; follow the output with `./platform.sh logs`.
exec "$(dirname "$0")/platform.sh" up spark "$@"
