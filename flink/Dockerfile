ARG FLINK_BASE_IMAGE=flink:1.14.6-scala_2.12-java8
FROM ${FLINK_BASE_IMAGE}

ARG FLINK_HADOOP_UBER_VERSION=2.8.3-10.0
ARG FLINK_VERSION=1.14.6
ARG FROCKSDBJNI_VERSION=6.20.3-ververica-1.0

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*
RUN curl -fsSL -o /opt/flink/lib/flink-shaded-hadoop-2-uber.jar \
      "https://repo1.maven.org/maven2/org/apache/flink/flink-shaded-hadoop-2-uber/${FLINK_HADOOP_UBER_VERSION}/flink-shaded-hadoop-2-uber-${FLINK_HADOOP_UBER_VERSION}.jar" \
    && test -s /opt/flink/lib/flink-shaded-hadoop-2-uber.jar \
    && curl -fsSL -o /opt/flink/lib/flink-statebackend-rocksdb.jar \
      "https://repo1.maven.org/maven2/org/apache/flink/flink-statebackend-rocksdb_2.12/${FLINK_VERSION}/flink-statebackend-rocksdb_2.12-${FLINK_VERSION}.jar" \
    && test -s /opt/flink/lib/flink-statebackend-rocksdb.jar \
    && curl -fsSL -o /opt/flink/lib/frocksdbjni.jar \
      "https://repo1.maven.org/maven2/com/ververica/frocksdbjni/${FROCKSDBJNI_VERSION}/frocksdbjni-${FROCKSDBJNI_VERSION}.jar" \
    && test -s /opt/flink/lib/frocksdbjni.jar
COPY conf/flink-conf.yaml /opt/flink/conf/flink-conf.yaml
USER flink
