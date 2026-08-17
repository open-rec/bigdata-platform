#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Roles:
#   metastore     Hive Metastore (thrift 9083)
#   hiveserver2   HiveServer2 (thrift 10000, web ui 10002)
#   schematool    create or upgrade the metastore schema, then exit (idempotent)
#   publish-libs  copy Hive's jars into /hive-libs, for Spark's metastore client
#   beeline       interactive client against hiveserver2
#   <other>       executed verbatim
#
# Connection settings come from /opt/hive/conf/hive-site.xml (baked in, and
# bind-mounted over in this platform's compose file so edits need no rebuild).
# ---------------------------------------------------------------------------
set -euo pipefail

export HIVE_HOME="${HIVE_HOME:-/opt/hive}"
export HADOOP_HOME="${HADOOP_HOME:-/opt/hadoop}"
DB_TYPE="${HIVE_DB_TYPE:-postgres}"

wait_for_metastore_db() {
  # schematool's own error on an unreachable database is opaque, so probe first.
  local host="${HIVE_DB_HOST:-hive-metastore-db}" port="${HIVE_DB_PORT:-5432}" attempt
  for attempt in $(seq 1 60); do
    if (exec 3<>"/dev/tcp/${host}/${port}") 2>/dev/null; then
      return 0
    fi
    echo "waiting for the metastore database at ${host}:${port} (${attempt}/60)..."
    sleep 2
  done
  echo "metastore database at ${host}:${port} never became reachable" >&2
  return 1
}

case "${1:-metastore}" in
  metastore)
    exec "${HIVE_HOME}/bin/hive" --service metastore
    ;;

  hiveserver2)
    exec "${HIVE_HOME}/bin/hive" --service hiveserver2
    ;;

  schematool)
    wait_for_metastore_db
    # -initOrUpgradeSchema is idempotent, so this is safe on every start.
    exec "${HIVE_HOME}/bin/schematool" -dbType "${DB_TYPE}" -initOrUpgradeSchema --verbose
    ;;

  publish-libs)
    target="${HIVE_LIBS_DIR:-/hive-libs}"
    mkdir -p "${target}"
    cp -n "${HIVE_HOME}"/lib/*.jar "${target}/" 2>/dev/null || true
    echo "$(find "${target}" -name '*.jar' | wc -l) jars in ${target}"
    ;;

  beeline)
    exec "${HIVE_HOME}/bin/beeline" -u "jdbc:hive2://${HIVESERVER2_HOST:-hiveserver2}:10000" -n hive
    ;;

  *)
    exec "$@"
    ;;
esac
