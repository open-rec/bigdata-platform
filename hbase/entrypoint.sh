#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# One image, four roles. HBASE_ROLE picks which daemon this container runs.
#
# Each is started through `hbase <role> start` rather than the hbase-daemon.sh
# wrappers: those fork into the background and write to log files, which would
# make the container exit immediately and hide its logs from `docker logs`.
# ---------------------------------------------------------------------------
set -euo pipefail

ROLE="${HBASE_ROLE:-master}"

case "${ROLE}" in
  master|regionserver|thrift|rest) ;;
  *)
    echo "HBASE_ROLE='${ROLE}' is not one of: master, regionserver, thrift, rest" >&2
    exit 64
    ;;
esac

# If anything was passed as a command, run that instead — this is what makes
# `docker compose run hbase-master hbase shell` and `platform.sh shell hbase`
# work.
if [[ $# -gt 0 ]]; then
  exec "$@"
fi

echo "starting hbase ${ROLE} (heap: ${HBASE_HEAPSIZE:-image default})"

exec "${HBASE_HOME}/bin/hbase" "${ROLE}" start
