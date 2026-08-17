# ---------------------------------------------------------------------------
# openrec/elasticsearch — Elasticsearch with this platform's settings and a
# self-signed certificate it generates for itself on first start.
#
# TLS and auth are on because the clients require them: rec-server's EsConfig
# and example/init's EsUtil both hardcode the https scheme and always send
# basic auth. Both also call withUnsafeTrustMaterial(), so a self-signed cert
# is fine and the CA never has to leave the container.
#
#   docker build -t openrec/elasticsearch:8.5.0 ./elasticsearch
#   docker run -d --name elasticsearch -p 9200:9200 \
#     -e ELASTIC_PASSWORD=openrec-es-password openrec/elasticsearch:8.5.0
#
# Needs vm.max_map_count >= 262144 on the host.
# ---------------------------------------------------------------------------

ARG ELASTIC_BASE_IMAGE=docker.elastic.co/elasticsearch/elasticsearch:8.5.0
FROM ${ELASTIC_BASE_IMAGE}

USER root

COPY conf/elasticsearch.yml /usr/share/elasticsearch/config/elasticsearch.yml
COPY entrypoint.sh /usr/local/bin/openrec-entrypoint.sh

# Elasticsearch refuses to run as root, so certificate generation happens as
# uid 1000. A fresh named volume mounted over config/certs inherits this
# directory's ownership, which is what makes that possible.
RUN mkdir -p /usr/share/elasticsearch/config/certs \
    && chown -R 1000:0 /usr/share/elasticsearch/config \
    && chmod 775 /usr/share/elasticsearch/config/certs \
    && chmod +x /usr/local/bin/openrec-entrypoint.sh

USER 1000

EXPOSE 9200 9300

ENTRYPOINT ["/usr/local/bin/openrec-entrypoint.sh"]
CMD ["server"]
