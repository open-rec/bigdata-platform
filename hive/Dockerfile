# ---------------------------------------------------------------------------
# openrec/hive — apache/hive plus the Postgres JDBC driver.
#
# The official image ships no JDBC driver at all, so a metastore backed by
# anything other than the embedded Derby DB cannot start without this.
# The driver is fetched in a separate stage because the Hive image is not
# guaranteed to have curl, and we do not want to run apt inside it.
# ---------------------------------------------------------------------------

ARG HIVE_VERSION=4.0.1
ARG PG_JDBC_VERSION=42.7.4

FROM curlimages/curl:latest AS jdbc
ARG PG_JDBC_VERSION
RUN curl -fsSL -o /tmp/postgresql.jar \
      "https://repo1.maven.org/maven2/org/postgresql/postgresql/${PG_JDBC_VERSION}/postgresql-${PG_JDBC_VERSION}.jar"

FROM apache/hive:${HIVE_VERSION}
ARG PG_JDBC_VERSION

USER root
COPY --from=jdbc --chown=hive:hive /tmp/postgresql.jar /opt/hive/lib/postgresql-${PG_JDBC_VERSION}.jar
USER hive
