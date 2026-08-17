# ---------------------------------------------------------------------------
# openrec/zookeeper — Apache ZooKeeper on a bare JRE.
#
# Built from the release tarball rather than wrapping a vendor image, so the
# only configuration surface is zoo.cfg, which entrypoint.sh renders from
# environment variables. Deployable on its own:
#
#   docker build -t openrec/zookeeper:3.9.2 ./zookeeper
#   docker run -d --name zk1 -p 2181:2181 \
#     -e ZOO_MY_ID=1 -e ZOO_SERVERS="server.1=zk1:2888:3888;2181" \
#     openrec/zookeeper:3.9.2
# ---------------------------------------------------------------------------

ARG JRE_BASE_IMAGE=eclipse-temurin:11-jre-jammy
FROM ${JRE_BASE_IMAGE}

ARG ZOOKEEPER_VERSION=3.9.2

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends curl ca-certificates bash netcat-openbsd procps; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    curl -fsSL -o /tmp/zookeeper.tar.gz \
      "https://mirrors.huaweicloud.com/apache/zookeeper/zookeeper-${ZOOKEEPER_VERSION}/apache-zookeeper-${ZOOKEEPER_VERSION}-bin.tar.gz"; \
    tar -xzf /tmp/zookeeper.tar.gz -C /opt; \
    ln -s "/opt/apache-zookeeper-${ZOOKEEPER_VERSION}-bin" /opt/zookeeper; \
    rm -f /tmp/zookeeper.tar.gz; \
    mkdir -p /var/lib/zookeeper/data /var/lib/zookeeper/log

ENV ZOOKEEPER_HOME=/opt/zookeeper \
    PATH=/opt/zookeeper/bin:$PATH \
    ZOO_DATA_DIR=/var/lib/zookeeper/data \
    ZOO_DATA_LOG_DIR=/var/lib/zookeeper/log \
    ZOO_CLIENT_PORT=2181 \
    ZOO_TICK_TIME=2000 \
    ZOO_INIT_LIMIT=5 \
    ZOO_SYNC_LIMIT=2 \
    ZOO_MY_ID=1 \
    ZOO_4LW_COMMANDS_WHITELIST=srvr,stat,ruok,mntr,conf \
    ZOO_LOG4J_PROP=INFO,CONSOLE

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# client, peer, leader election
EXPOSE 2181 2888 3888

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["server"]
