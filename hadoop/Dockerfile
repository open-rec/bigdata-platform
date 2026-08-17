# ---------------------------------------------------------------------------
# openrec/hadoop — HDFS and YARN with this platform's configuration baked in.
#
# The upstream apache/hadoop image expects configuration as environment
# variables named CORE-SITE.XML_<property>, which it translates into XML at
# startup. This image ships real config files under conf/ instead: the settings
# are reviewable, they are identical whether you use compose or `docker run`,
# and there is no translation step to get wrong.
#
# One image, four roles (see entrypoint.sh):
#
#   docker build -t openrec/hadoop:3.3.6 ./hadoop
#   docker run -d --name namenode -p 9870:9870 -p 8020:8020 openrec/hadoop:3.3.6 namenode
#   docker run -d --name datanode-1 openrec/hadoop:3.3.6 datanode
# ---------------------------------------------------------------------------

ARG HADOOP_BASE_IMAGE=apache/hadoop:3.3.6
FROM ${HADOOP_BASE_IMAGE}

USER root

ENV HADOOP_HOME=/opt/hadoop \
    HADOOP_CONF_DIR=/opt/hadoop/etc/hadoop \
    PATH=/opt/hadoop/bin:/opt/hadoop/sbin:$PATH \
    HDFS_NAME_DIR=/opt/hadoop/dfs/name \
    HDFS_DATA_DIR=/opt/hadoop/dfs/data \
    HADOOP_TMP_DIR=/opt/hadoop/tmp \
    HDFS_CLUSTER_ID=openrec

# Paths here must match dfs.namenode.name.dir / dfs.datanode.data.dir in
# conf/hdfs-site.xml. World-writable so the image also works when run as a
# non-root user with a fresh named volume mounted over these directories.
RUN mkdir -p ${HDFS_NAME_DIR} ${HDFS_DATA_DIR} ${HADOOP_TMP_DIR} \
    && chmod -R 777 /opt/hadoop/dfs ${HADOOP_TMP_DIR}

COPY conf/core-site.xml conf/hdfs-site.xml conf/yarn-site.xml conf/mapred-site.xml ${HADOOP_CONF_DIR}/
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# namenode rpc / namenode ui / datanode ui / datanode xfer / rm ui / nm ui
EXPOSE 8020 9870 9864 9866 8088 8042

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["namenode"]
