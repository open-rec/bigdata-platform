#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# open-rec bigdata-platform control script.
#
# Wraps docker compose so you name a *component* and get its dependency
# closure of profiles. `up hive` starts HDFS and YARN too, because a Hive
# warehouse without them is not a warehouse.
#
#   ./platform.sh up [component...]     default: all
#   ./platform.sh down [-v]             -v also deletes the volumes (all data)
#   ./platform.sh ps
#   ./platform.sh logs [service...]
#   ./platform.sh restart [service...]
#   ./platform.sh build [component...]  only hive / hbase / spark are built
#   ./platform.sh pull
#   ./platform.sh init [component...]   re-run the bootstrap one-shots
#   ./platform.sh smoke [component...]  verify what is running
#   ./platform.sh shell <target>        zk|kafka|hdfs|hive|hbase|spark
#   ./platform.sh config                resolved compose config
# ---------------------------------------------------------------------------
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

readonly COMPONENTS=(zookeeper kafka hdfs yarn hive hbase spark)

# --- docker compose v2 / v1 ------------------------------------------------
if docker compose version >/dev/null 2>&1; then
  DC=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  DC=(docker-compose)
else
  echo "error: neither 'docker compose' nor 'docker-compose' is available" >&2
  exit 1
fi

# --- helpers ---------------------------------------------------------------
die() { echo "error: $*" >&2; exit 1; }
note() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

# Profiles a component needs, itself included. This is the whole reason this
# script exists: compose will not infer that Hive needs HDFS.
profiles_for() {
  case "$1" in
    zookeeper) echo "zookeeper" ;;
    kafka)     echo "zookeeper kafka" ;;
    hdfs)      echo "hdfs" ;;
    yarn)      echo "hdfs yarn" ;;
    hive)      echo "hdfs yarn hive" ;;
    hbase)     echo "zookeeper hdfs hbase" ;;
    spark)     echo "hdfs spark" ;;
    all)       echo "${COMPONENTS[*]}" ;;
    *)         die "unknown component '$1' (valid: ${COMPONENTS[*]} all)" ;;
  esac
}

# Names must be checked here, in the main shell: profiles_for runs inside a
# process substitution below, where die() can only kill the subshell — an
# unknown component would otherwise silently expand to no profiles at all.
validate_components() {
  local component
  for component in "$@"; do
    case "$component" in
      zookeeper|kafka|hdfs|yarn|hive|hbase|spark|all) ;;
      *) die "unknown component '$component' (valid: ${COMPONENTS[*]} all)" ;;
    esac
  done
}

# Turns component names into a deduplicated --profile argument list.
profile_args() {
  local -a wanted=()
  local component profile
  for component in "$@"; do
    for profile in $(profiles_for "$component"); do
      wanted+=("$profile")
    done
  done
  printf '%s\n' "${wanted[@]}" | sort -u | while read -r profile; do
    printf -- '--profile\n%s\n' "$profile"
  done
}

# Every profile, for commands that should see the whole platform (ps, logs,
# down): a service whose profile is not enabled is invisible to compose.
all_profile_args() {
  local profile
  for profile in "${COMPONENTS[@]}"; do
    printf -- '--profile\n%s\n' "$profile"
  done
}

compose() {
  local -a args=()
  mapfile -t args < <(all_profile_args)
  "${DC[@]}" "${args[@]}" "$@"
}

compose_for() {
  local components="$1"; shift
  local -a args=()
  mapfile -t args < <(profile_args $components)
  "${DC[@]}" "${args[@]}" "$@"
}

running() {
  [[ -n "$(compose ps -q "$1" 2>/dev/null)" ]]
}

# Services built from a Dockerfile, per component.
build_targets() {
  case "$1" in
    hive)  echo "hive-metastore hiveserver2 hive-schema-init hive-libs-init" ;;
    hbase) echo "hbase-master hbase-regionserver-1 hbase-regionserver-2 hbase-thrift" ;;
    spark) echo "spark-master spark-worker-1 spark-worker-2 spark-history jupyterlab" ;;
    *)     echo "" ;;
  esac
}

# Bootstrap one-shots, per component. Each is idempotent.
init_targets() {
  case "$1" in
    hdfs)  echo "hdfs-init" ;;
    kafka) echo "kafka-init" ;;
    hive)  echo "hive-schema-init hive-libs-init" ;;
    *)     echo "" ;;
  esac
}

# --- commands --------------------------------------------------------------
cmd_up() {
  local -a components=("$@")
  if [[ ${#components[@]} -eq 0 ]]; then components=(all); fi
  validate_components "${components[@]}"
  note "starting: ${components[*]}"
  compose_for "${components[*]}" up -d
  note "state"
  compose ps
  cat <<'EOF'

Bring-up is asynchronous: healthchecks and the bootstrap one-shots take a
minute or two on a cold start. Watch with `./platform.sh ps` and verify with
`./platform.sh smoke`.
EOF
}

cmd_down() {
  note "stopping platform"
  compose down "$@"
}

cmd_ps() { compose ps "$@"; }

cmd_logs() {
  if [[ $# -eq 0 ]]; then
    compose logs -f --tail=200
  else
    compose logs -f --tail=200 "$@"
  fi
}

cmd_restart() {
  [[ $# -eq 0 ]] && die "restart needs at least one service name (see ./platform.sh ps)"
  compose restart "$@"
}

cmd_build() {
  local -a components=("$@")
  if [[ ${#components[@]} -eq 0 ]]; then components=(hive hbase spark); fi
  validate_components "${components[@]}"
  local component target
  local -a targets=()
  for component in "${components[@]}"; do
    for target in $(build_targets "$component"); do
      targets+=("$target")
    done
  done
  if [[ ${#targets[@]} -eq 0 ]]; then
    note "nothing to build for: ${components[*]} (only hive, hbase and spark are built locally)"
    return 0
  fi
  note "building images for: ${components[*]}"
  compose build "${targets[@]}"
}

cmd_pull() {
  note "pulling third-party images (locally built ones are skipped)"
  # --ignore-buildable landed in a later compose 2.x; fall back for older ones,
  # where pulling the locally-built images fails and is ignored instead.
  compose pull --ignore-buildable 2>/dev/null \
    || compose pull --ignore-pull-failures
}

cmd_init() {
  local -a components=("$@")
  if [[ ${#components[@]} -eq 0 ]]; then components=("${COMPONENTS[@]}"); fi
  validate_components "${components[@]}"
  local component target
  for component in "${components[@]}"; do
    for target in $(init_targets "$component"); do
      note "init: $target"
      compose run --rm --no-deps "$target"
    done
  done
}

check() {
  local label="$1"; shift
  local output
  printf '  %-34s' "$label"
  if output=$("$@" 2>&1); then
    printf 'ok\n'
    if [[ -n "${SMOKE_VERBOSE:-}" ]]; then sed 's/^/      /' <<<"$output"; fi
  else
    printf 'FAILED\n'
    sed 's/^/      /' <<<"$output"
    SMOKE_FAILED=1
  fi
  # Explicit: a non-zero return here would trip `set -e` in the caller.
  return 0
}

smoke_zookeeper() {
  local i
  for i in 1 2 3; do
    check "zookeeper-$i serving" compose exec -T "zookeeper-$i" \
      bash -c 'exec 3<>/dev/tcp/127.0.0.1/2181; printf srvr >&3; grep -E "^Mode: (leader|follower)" <&3'
  done
}

smoke_kafka() {
  check "kafka topics" compose exec -T kafka-1 \
    kafka-topics --bootstrap-server kafka-1:9092 --list
  check "kafka topic 'event' replicated" compose exec -T kafka-1 \
    bash -c 'kafka-topics --bootstrap-server kafka-1:9092 --describe --topic event | grep -q "ReplicationFactor: 3"'
}

smoke_hdfs() {
  check "hdfs live datanodes" compose exec -T namenode \
    bash -c 'hdfs dfsadmin -report | grep -E "^Live datanodes" | grep -qv "(0)"'
  check "hdfs warehouse dir" compose exec -T namenode \
    hdfs dfs -test -d /user/hive/warehouse
  check "hdfs spark-logs dir" compose exec -T namenode \
    hdfs dfs -test -d /spark-logs
}

smoke_yarn() {
  check "yarn nodemanagers running" compose exec -T resourcemanager \
    bash -c 'yarn node -list 2>/dev/null | grep -q RUNNING'
}

smoke_hive() {
  check "hiveserver2 query" compose exec -T hiveserver2 \
    beeline -u jdbc:hive2://hiveserver2:10000 -n hive --silent=true -e 'show databases;'
}

smoke_hbase() {
  check "hbase cluster status" compose exec -T hbase-master \
    bash -c 'echo "status" | hbase shell -n'
  check "hbase thrift port" compose exec -T hbase-thrift \
    bash -c 'exec 3<>/dev/tcp/127.0.0.1/9090'
}

smoke_spark() {
  check "spark alive workers" compose exec -T spark-master python3 -c '
import json, sys, urllib.request
d = json.load(urllib.request.urlopen("http://spark-master:8080/json/"))
alive = [w for w in d.get("workers", []) if w.get("state") == "ALIVE"]
print("alive workers:", len(alive))
sys.exit(0 if alive else 1)'
}

cmd_smoke() {
  local -a components=("$@")
  if [[ ${#components[@]} -eq 0 ]]; then components=("${COMPONENTS[@]}"); fi
  validate_components "${components[@]}"
  SMOKE_FAILED=0
  local component
  for component in "${components[@]}"; do
    case "$component" in
      zookeeper) running zookeeper-1   || { note "zookeeper: not running, skipped"; continue; } ;;
      kafka)     running kafka-1       || { note "kafka: not running, skipped"; continue; } ;;
      hdfs)      running namenode      || { note "hdfs: not running, skipped"; continue; } ;;
      yarn)      running resourcemanager || { note "yarn: not running, skipped"; continue; } ;;
      hive)      running hiveserver2   || { note "hive: not running, skipped"; continue; } ;;
      hbase)     running hbase-master  || { note "hbase: not running, skipped"; continue; } ;;
      spark)     running spark-master  || { note "spark: not running, skipped"; continue; } ;;
      *)         die "unknown component '$component'" ;;
    esac
    note "$component"
    "smoke_$component"
  done
  if [[ "$SMOKE_FAILED" -ne 0 ]]; then
    note "smoke test FAILED — see above (logs: ./platform.sh logs <service>)"
    return 1
  fi
  note "all checks passed"
}

cmd_shell() {
  local target="${1:-}"
  case "$target" in
    zk)    compose exec zookeeper-1 zookeeper-shell localhost:2181 ;;
    kafka) compose exec kafka-1 bash ;;
    hdfs)  compose exec namenode bash ;;
    hive)  compose exec hiveserver2 beeline -u jdbc:hive2://hiveserver2:10000 -n hive ;;
    hbase) compose exec hbase-master hbase shell ;;
    spark) compose exec spark-master /opt/spark/bin/spark-sql ;;
    *)     die "shell target must be one of: zk kafka hdfs hive hbase spark" ;;
  esac
}

usage() {
  cat <<EOF
open-rec bigdata-platform — docker compose control script

  ./platform.sh up [component...]     start components and their dependencies
                                      (default: all)
  ./platform.sh down [-v]             stop everything; -v also deletes volumes
  ./platform.sh ps                    container state
  ./platform.sh logs [service...]     follow logs
  ./platform.sh restart <service...>  restart named services
  ./platform.sh build [component...]  build the local images (hive/hbase/spark)
  ./platform.sh pull                  pre-pull third-party images
  ./platform.sh init [component...]   re-run the bootstrap one-shots
  ./platform.sh smoke [component...]  verify whatever is running
  ./platform.sh shell <target>        zk | kafka | hdfs | hive | hbase | spark
  ./platform.sh config                dump the resolved compose config

components: ${COMPONENTS[*]} all

dependency closures (what 'up <component>' actually starts):
  kafka -> zookeeper kafka          hive  -> hdfs yarn hive
  yarn  -> hdfs yarn                hbase -> zookeeper hdfs hbase
  spark -> hdfs spark
EOF
}

main() {
  local cmd="${1:-}"
  [[ $# -gt 0 ]] && shift || true
  case "$cmd" in
    up)      cmd_up "$@" ;;
    down)    cmd_down "$@" ;;
    ps)      cmd_ps "$@" ;;
    logs)    cmd_logs "$@" ;;
    restart) cmd_restart "$@" ;;
    build)   cmd_build "$@" ;;
    pull)    cmd_pull "$@" ;;
    init)    cmd_init "$@" ;;
    smoke)   cmd_smoke "$@" ;;
    shell)   cmd_shell "$@" ;;
    config)  compose config ;;
    ""|-h|--help|help) usage ;;
    *)       usage; die "unknown command '$cmd'" ;;
  esac
}

main "$@"
