ARG FLINK_BASE_IMAGE=flink:2.2.1-java21
FROM ${FLINK_BASE_IMAGE}

ARG HADOOP_CLIENT_VERSION=3.4.1

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*
# Hadoop's shaded client avoids bringing a second copy of Flink's dependencies.
# RocksDB is included in flink-dist in Flink 2; do not inject the old 1.14 backend.
RUN set -eu; for artifact in hadoop-client-api hadoop-client-runtime; do \
      curl --retry 3 -fsSL -o "/opt/flink/lib/${artifact}-${HADOOP_CLIENT_VERSION}.jar" \
        "https://repo.maven.apache.org/maven2/org/apache/hadoop/${artifact}/${HADOOP_CLIENT_VERSION}/${artifact}-${HADOOP_CLIENT_VERSION}.jar"; \
    done \
    && curl --retry 3 -fsSL -o /opt/flink/lib/commons-logging-1.3.4.jar \
      https://repo.maven.apache.org/maven2/commons-logging/commons-logging/1.3.4/commons-logging-1.3.4.jar
COPY conf/flink-conf.yaml /tmp/openrec-flink.properties
# Merge into the upstream YAML; retain all upstream Java module opens/exports.
RUN set -eu; set --; \
    while IFS= read -r line; do \
      case "$line" in ''|'#'*) continue ;; esac; \
      key="${line%%:*}"; value="${line#*: }"; set -- "$@" -D"${key}=${value}"; \
    done < /tmp/openrec-flink.properties; \
    /opt/flink/bin/config-parser-utils.sh /opt/flink/conf /opt/flink/bin /opt/flink/lib "$@"; \
    chown flink:flink /opt/flink/conf/config.yaml
USER flink
