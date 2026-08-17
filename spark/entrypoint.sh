#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Roles:
#   master    standalone cluster master (7077, ui 8080)
#   worker    standalone worker, registers with SPARK_MASTER_URL
#   history   history server over the event log on HDFS (ui 18080)
#   jupyter   JupyterLab (8888) with pyspark available
#   submit    spark-submit, remaining args passed through
#   sql       spark-sql shell
#   <other>   executed verbatim
#
# The daemons run through spark-class rather than the sbin/start-*.sh scripts:
# those daemonise and log to files, which makes the container exit immediately
# and hides its output from `docker logs`.
# ---------------------------------------------------------------------------
set -euo pipefail

SPARK_HOME="${SPARK_HOME:-/opt/spark}"
MASTER_URL="${SPARK_MASTER_URL:-spark://spark-master:7077}"
ROLE="${1:-master}"
[[ $# -gt 0 ]] && shift || true

case "${ROLE}" in
  master)
    exec "${SPARK_HOME}/bin/spark-class" org.apache.spark.deploy.master.Master \
      --host "${SPARK_MASTER_HOST:-spark-master}" \
      --port "${SPARK_MASTER_PORT:-7077}" \
      --webui-port "${SPARK_MASTER_WEBUI_PORT:-8080}" "$@"
    ;;

  worker)
    exec "${SPARK_HOME}/bin/spark-class" org.apache.spark.deploy.worker.Worker \
      --webui-port "${SPARK_WORKER_WEBUI_PORT:-8081}" \
      --cores "${SPARK_WORKER_CORES:-2}" \
      --memory "${SPARK_WORKER_MEMORY:-2g}" \
      "${MASTER_URL}" "$@"
    ;;

  history)
    # spark.history.fs.logDirectory comes from spark-defaults.conf.
    exec "${SPARK_HOME}/bin/spark-class" org.apache.spark.deploy.history.HistoryServer "$@"
    ;;

  jupyter)
    exec jupyter lab \
      --ip=0.0.0.0 \
      --port="${JUPYTER_PORT:-8888}" \
      --no-browser \
      --ServerApp.token="${JUPYTER_TOKEN:-}" \
      --ServerApp.password= \
      --notebook-dir="${JUPYTER_WORKDIR:-/opt/workspace}" "$@"
    ;;

  submit)
    exec "${SPARK_HOME}/bin/spark-submit" --master "${MASTER_URL}" "$@"
    ;;

  sql)
    exec "${SPARK_HOME}/bin/spark-sql" "$@"
    ;;

  *)
    exec "${ROLE}" "$@"
    ;;
esac
