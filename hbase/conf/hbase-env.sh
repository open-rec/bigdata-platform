# ---------------------------------------------------------------------------
# HBase environment for containerised operation.
# ---------------------------------------------------------------------------

# ZooKeeper is a first-class service of this platform (profile: zookeeper), not
# something HBase should start for itself.
export HBASE_MANAGES_ZK=false

# Heap comes from the container env (HBASE_HEAPSIZE is set per service in
# docker-compose.yml); this is only the fallback.
export HBASE_HEAPSIZE=${HBASE_HEAPSIZE:-1g}

# Log to the console so `docker logs` / `platform.sh logs` show something.
# Without this HBase writes to $HBASE_HOME/logs and the container looks silent.
export HBASE_ROOT_LOGGER=${HBASE_ROOT_LOGGER:-INFO,console}
export HBASE_SECURITY_LOGGER=${HBASE_SECURITY_LOGGER:-INFO,console}

# Respect the container's cgroup limits when sizing the heap and GC threads.
export HBASE_OPTS="${HBASE_OPTS} -XX:+UseContainerSupport -Djava.net.preferIPv4Stack=true"

# Silence the "HBASE_HOME is deprecated" style warnings from the launcher.
export HBASE_DISABLE_HADOOP_CLASSPATH_LOOKUP=${HBASE_DISABLE_HADOOP_CLASSPATH_LOOKUP:-true}
