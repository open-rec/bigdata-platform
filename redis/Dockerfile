# ---------------------------------------------------------------------------
# openrec/redis — Redis with the serving-layer config baked in.
#
# Thin on purpose: the upstream image is already the product, all this adds is
# redis.conf so the container behaves the same however it is started.
#
#   docker build -t openrec/redis:7.2-alpine ./redis
#   docker run -d --name redis -p 6379:6379 openrec/redis:7.2-alpine
#   docker run -d --name redis openrec/redis:7.2-alpine --maxmemory 8gb
#
# Extra redis-server flags passed to `docker run` are appended after the config
# file, and command-line options win over it.
# ---------------------------------------------------------------------------

ARG REDIS_BASE_IMAGE=redis:7.2-alpine
FROM ${REDIS_BASE_IMAGE}

COPY redis.conf /etc/redis/redis.conf

VOLUME /data
WORKDIR /data
EXPOSE 6379

ENTRYPOINT ["redis-server", "/etc/redis/redis.conf"]
