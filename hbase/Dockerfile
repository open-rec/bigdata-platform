# ---------------------------------------------------------------------------
# openrec/hbase — Apache does not publish an official HBase image, so this
# unpacks the release tarball onto a JRE base.
#
# archive.apache.org is used on purpose: dlcdn.apache.org only carries the
# current release, so a pinned older version would 404 there after the next
# HBase release.
#
# One image, four roles, given as the container's argument (see entrypoint.sh):
#
#   docker build -t openrec/hbase:2.5.10 ./hbase
#   docker run -d --name hbase-master -p 16010:16010 openrec/hbase:2.5.10 master
#   docker run -d --name hbase-rs-1 openrec/hbase:2.5.10 regionserver
#   docker run --rm -it openrec/hbase:2.5.10 hbase shell
# ---------------------------------------------------------------------------

ARG HBASE_JDK_IMAGE=eclipse-temurin:11-jre-jammy
FROM ${HBASE_JDK_IMAGE}

ARG HBASE_VERSION=2.5.10

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends curl ca-certificates bash procps; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    curl -fsSL -o /tmp/hbase.tar.gz \
      "https://archive.apache.org/dist/hbase/${HBASE_VERSION}/hbase-${HBASE_VERSION}-bin.tar.gz"; \
    mkdir -p /opt; \
    tar -xzf /tmp/hbase.tar.gz -C /opt; \
    ln -s "/opt/hbase-${HBASE_VERSION}" /opt/hbase; \
    rm -f /tmp/hbase.tar.gz; \
    # The bundled docs are ~100MB of HTML that nothing in a container reads.
    rm -rf "/opt/hbase-${HBASE_VERSION}/docs"; \
    mkdir -p /tmp/hbase

ENV HBASE_HOME=/opt/hbase \
    HBASE_CONF_DIR=/opt/hbase/conf \
    PATH=/opt/hbase/bin:$PATH

COPY conf/hbase-site.xml conf/hbase-env.sh /opt/hbase/conf/
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# master 16000/16010, regionserver 16020/16030, thrift 9090/9095, rest 8080/8085
EXPOSE 16000 16010 16020 16030 9090 9095

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["master"]
