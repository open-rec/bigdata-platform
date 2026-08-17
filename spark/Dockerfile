# ---------------------------------------------------------------------------
# openrec/spark — apache/spark plus what it needs to be useful here:
#
#   * the spark-sql-kafka connector, so structured streaming can read the
#     platform's Kafka topics without --packages resolving from the internet
#     on every job submit
#   * JupyterLab, preserving the notebook entry point on :8888
#   * happybase, the practical way to write to HBase from PySpark (through the
#     Thrift gateway) — the JVM hbase-spark connector is version-fragile
#
# Jars are downloaded in a separate stage: the Spark image is not guaranteed to
# ship curl, and this keeps the download layer out of the final image.
#
# One image, several roles (see entrypoint.sh):
#
#   docker build -t openrec/spark:3.5.3 ./spark
#   docker run -d --name spark-master -p 8080:8080 -p 7077:7077 openrec/spark:3.5.3 master
#   docker run -d --name spark-worker -e SPARK_MASTER_URL=spark://spark-master:7077 \
#     openrec/spark:3.5.3 worker
#   docker run --rm openrec/spark:3.5.3 submit /opt/workspace/job.py
# ---------------------------------------------------------------------------

ARG SPARK_BASE_IMAGE=apache/spark:3.5.3-python3

FROM curlimages/curl:latest AS jars
ARG SPARK_VERSION=3.5.3
ARG SCALA_BINARY=2.12
ARG KAFKA_CLIENTS_VERSION=3.4.1
ARG COMMONS_POOL2_VERSION=2.11.1
ENV MAVEN=https://repo1.maven.org/maven2
RUN set -eux; \
    mkdir -p /tmp/jars; \
    cd /tmp/jars; \
    curl -fsSLO "${MAVEN}/org/apache/spark/spark-sql-kafka-0-10_${SCALA_BINARY}/${SPARK_VERSION}/spark-sql-kafka-0-10_${SCALA_BINARY}-${SPARK_VERSION}.jar"; \
    curl -fsSLO "${MAVEN}/org/apache/spark/spark-token-provider-kafka-0-10_${SCALA_BINARY}/${SPARK_VERSION}/spark-token-provider-kafka-0-10_${SCALA_BINARY}-${SPARK_VERSION}.jar"; \
    curl -fsSLO "${MAVEN}/org/apache/kafka/kafka-clients/${KAFKA_CLIENTS_VERSION}/kafka-clients-${KAFKA_CLIENTS_VERSION}.jar"; \
    curl -fsSLO "${MAVEN}/org/apache/commons/commons-pool2/${COMMONS_POOL2_VERSION}/commons-pool2-${COMMONS_POOL2_VERSION}.jar"; \
    ls -l /tmp/jars

FROM ${SPARK_BASE_IMAGE}

ARG JUPYTERLAB_VERSION=4.2.5
ARG HAPPYBASE_VERSION=1.2.0

USER root

COPY --from=jars /tmp/jars/ /opt/spark/jars/

# PEP 668 marks the distro Python as externally managed on newer bases; pip
# below 23 ignores this variable, so it is safe either way.
ENV PIP_BREAK_SYSTEM_PACKAGES=1
RUN set -eux; \
    if ! python3 -m pip --version >/dev/null 2>&1; then \
      apt-get update; \
      apt-get install -y --no-install-recommends python3-pip; \
      rm -rf /var/lib/apt/lists/*; \
    fi; \
    python3 -m pip install --no-cache-dir \
      --index-url https://mirrors.aliyun.com/pypi/simple/ \
      "jupyterlab==${JUPYTERLAB_VERSION}" \
      "happybase==${HAPPYBASE_VERSION}" \
      pandas pyarrow

# Shared scratch space. A named volume mounted here inherits these permissions
# on first use, which is what lets the non-root spark user and JupyterLab both
# write to it.
RUN mkdir -p /opt/workspace && chmod 777 /opt/workspace

# Mounted read-only from the hive profile's hive-libs volume; created here so
# the path exists even when the hive profile is not running.
RUN mkdir -p /opt/hive-libs && chmod 755 /opt/hive-libs

ENV PYSPARK_PYTHON=python3 \
    PYSPARK_DRIVER_PYTHON=python3 \
    HOME=/opt/workspace

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER spark
WORKDIR /opt/workspace

# master ui / worker ui / history ui / jupyterlab / driver ui / master rpc
EXPOSE 8080 8081 18080 8888 4040 7077

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["master"]
