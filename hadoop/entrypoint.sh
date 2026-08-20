#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Roles:
#   namenode         formats on first start, then runs the namenode
#   secondarynamenode
#   datanode
#   resourcemanager
#   nodemanager
#   historyserver    MapReduce job history server
#   init             wait for HDFS, then create the directories Hive, HBase and
#                    Spark expect (idempotent)
#   <other>          executed verbatim: `hdfs dfs -ls /`, `yarn node -list`, bash
# ---------------------------------------------------------------------------
set -euo pipefail

ROLE="${1:-namenode}"

wait_for_hdfs() {
  local attempt
  for attempt in $(seq 1 60); do
    if "${HADOOP_HOME}/bin/hdfs" dfs -ls / >/dev/null 2>&1; then
      return 0
    fi
    echo "waiting for hdfs to accept requests (${attempt}/60)..."
    sleep 3
  done
  echo "hdfs never became available" >&2
  return 1
}

wait_for_writable_hdfs() {
  local attempt state
  for attempt in $(seq 1 60); do
    state="$("${HADOOP_HOME}/bin/hdfs" dfsadmin -safemode get 2>/dev/null || true)"
    if grep -Fq "Safe mode is OFF" <<<"${state}"; then
      return 0
    fi
    echo "waiting for hdfs safe mode to turn off (${attempt}/60): ${state:-unavailable}"
    sleep 3
  done
  echo "hdfs remained in safe mode and cannot accept initialization writes" >&2
  return 1
}

case "${ROLE}" in
  namenode)
    # "Formatted" means the name dir holds a current/VERSION file. Checking for
    # that rather than for the directory itself is what lets a named volume be
    # mounted straight onto ${HDFS_NAME_DIR}: an empty-but-existing directory
    # still gets formatted.
    if [[ ! -f "${HDFS_NAME_DIR}/current/VERSION" ]]; then
      echo "namenode is unformatted, formatting cluster '${HDFS_CLUSTER_ID}'..."
      "${HADOOP_HOME}/bin/hdfs" namenode -format -force -nonInteractive \
        -clusterId "${HDFS_CLUSTER_ID}"
    else
      echo "namenode already formatted, skipping format"
    fi
    exec "${HADOOP_HOME}/bin/hdfs" namenode
    ;;

  secondarynamenode)
    exec "${HADOOP_HOME}/bin/hdfs" secondarynamenode
    ;;

  datanode)
    exec "${HADOOP_HOME}/bin/hdfs" datanode
    ;;

  resourcemanager)
    exec "${HADOOP_HOME}/bin/yarn" resourcemanager
    ;;

  nodemanager)
    exec "${HADOOP_HOME}/bin/yarn" nodemanager
    ;;

  historyserver)
    exec "${HADOOP_HOME}/bin/mapred" historyserver
    ;;

  init)
    wait_for_hdfs
    # A restarted namenode can answer reads while it is still rebuilding its
    # block map. Mutating commands fail during this safe-mode extension, so do
    # not treat a successful `hdfs dfs -ls /` as write readiness.
    wait_for_writable_hdfs
    hdfs="${HADOOP_HOME}/bin/hdfs"
    # /user/hive/warehouse  Hive's warehouse root
    # /spark-logs           Spark event logs, read by the history server
    # /hbase                HBase's rootdir
    # /apps/tez             Tez runtime archive published by HiveServer2
    # /openrec              raw/features plus Flink/Spark durable state
    "${hdfs}" dfs -mkdir -p /tmp /user /user/hive/warehouse /user/spark /spark-logs /hbase /apps/tez \
      /openrec/raw/user /openrec/raw/item /openrec/raw/event /openrec/features \
      /openrec/checkpoints/flink /openrec/checkpoints/spark-features /openrec/savepoints/flink
    "${hdfs}" dfs -chmod -R 1777 /tmp
    "${hdfs}" dfs -chmod -R 777 /user/hive/warehouse /user/spark /spark-logs /apps/tez /openrec
    echo "--- hdfs layout ---"
    exec "${hdfs}" dfs -ls -R /
    ;;

  *)
    exec "$@"
    ;;
esac
