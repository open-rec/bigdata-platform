# ---------------------------------------------------------------------------
# openrec/hive — Hive with the Postgres JDBC driver and this platform's
# hive-site.xml baked in.
#
# Two things the upstream image does not give us:
#   * a JDBC driver — it ships none, so a metastore backed by anything other
#     than embedded Derby cannot start
#   * a predictable launch path — its entrypoint drives everything through
#     SERVICE_NAME/IS_RESUME/HIVE_CUSTOM_CONF_DIR. entrypoint.sh here calls
#     `hive --service ...` and `schematool` directly instead, which is plain
#     Hive and behaves the same in every deployment.
#
#   docker build -t openrec/hive:4.0.1 ./hive
#   docker run -d --name hive-metastore -p 9083:9083 openrec/hive:4.0.1 metastore
#   docker run --rm openrec/hive:4.0.1 schematool
# ---------------------------------------------------------------------------

ARG HIVE_BASE_IMAGE=apache/hive:4.0.1
ARG PG_JDBC_VERSION=42.7.4

FROM curlimages/curl:latest AS jdbc
ARG PG_JDBC_VERSION
RUN curl -fsSL -o /tmp/postgresql.jar \
      "https://repo1.maven.org/maven2/org/postgresql/postgresql/${PG_JDBC_VERSION}/postgresql-${PG_JDBC_VERSION}.jar"

FROM ${HIVE_BASE_IMAGE}
ARG PG_JDBC_VERSION

USER root
COPY --from=jdbc /tmp/postgresql.jar /opt/hive/lib/postgresql-${PG_JDBC_VERSION}.jar
COPY conf/hive-site.xml /opt/hive/conf/hive-site.xml
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh \
    && chown -R hive:hive /opt/hive/conf /opt/hive/lib 2>/dev/null || true

USER hive

# metastore thrift / hiveserver2 thrift / hiveserver2 web ui
EXPOSE 9083 10000 10002

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["metastore"]
