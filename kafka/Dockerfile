# ---------------------------------------------------------------------------
# openrec/kafka — Apache Kafka on a bare JRE.
#
# entrypoint.sh turns KAFKA_* environment variables into server.properties
# entries (broker.id, advertised.listeners, ...), which is the same convention
# Confluent's images use, so existing compose environments carry over.
# Deployable on its own:
#
#   docker build -t openrec/kafka:3.7.1 ./kafka
#   docker run -d --name kafka-1 -p 9092:9092 \
#     -e KAFKA_BROKER_ID=1 \
#     -e KAFKA_ZOOKEEPER_CONNECT=zk1:2181 \
#     -e KAFKA_LISTENERS=PLAINTEXT://0.0.0.0:9092 \
#     -e KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://localhost:9092 \
#     openrec/kafka:3.7.1
#
# Kafka 3.7 still supports ZooKeeper mode (KRaft is the default upstream but
# this platform runs ZooKeeper deliberately — HBase needs the ensemble anyway).
# ---------------------------------------------------------------------------

ARG JRE_BASE_IMAGE=eclipse-temurin:11-jre-jammy
FROM ${JRE_BASE_IMAGE}

ARG KAFKA_VERSION=3.7.1
ARG KAFKA_SCALA_VERSION=2.13

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends curl ca-certificates bash netcat-openbsd procps; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    curl -fsSL -o /tmp/kafka.tgz \
      "https://archive.apache.org/dist/kafka/${KAFKA_VERSION}/kafka_${KAFKA_SCALA_VERSION}-${KAFKA_VERSION}.tgz"; \
    tar -xzf /tmp/kafka.tgz -C /opt; \
    ln -s "/opt/kafka_${KAFKA_SCALA_VERSION}-${KAFKA_VERSION}" /opt/kafka; \
    rm -f /tmp/kafka.tgz; \
    mkdir -p /var/lib/kafka/data

ENV KAFKA_HOME=/opt/kafka \
    PATH=/opt/kafka/bin:$PATH \
    KAFKA_LOG_DIRS=/var/lib/kafka/data \
    KAFKA_HEAP_OPTS="-Xmx1g -Xms1g"

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 9092

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["broker"]
