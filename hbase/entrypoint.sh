#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# One image, four roles, taken from the first argument (or HBASE_ROLE):
#
#   master        HBase master (16000, ui 16010)
#   regionserver  region server (16020, ui 16030)
#   thrift        Thrift gateway (9090, ui 9095) — the entry point for Python
#   rest          REST gateway (8080, ui 8085)
#   <other>       executed verbatim, e.g. `hbase shell` or `bash`
#
# Each is started through `hbase <role> start` rather than the hbase-daemon.sh
# wrappers: those fork into the background and write to log files, which would
# make the container exit immediately and hide its logs from `docker logs`.
# ---------------------------------------------------------------------------
set -euo pipefail

ROLE="${1:-${HBASE_ROLE:-master}}"

case "${ROLE}" in
  master|regionserver|thrift|rest)
    echo "starting hbase ${ROLE} (heap: ${HBASE_HEAPSIZE:-image default})"
    exec "${HBASE_HOME}/bin/hbase" "${ROLE}" start
    ;;
  *)
    # Anything else is a command: `hbase shell`, `bash`, `hbase hbck`, ...
    exec "$@"
    ;;
esac
