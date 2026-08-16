# bigdata-platform

Docker Compose definitions for the infrastructure that open-rec's **cluster** mode runs on:
ZooKeeper, Kafka and Spark. Standalone mode does not need any of this — see
[example_standalone](https://github.com/open-rec/example/tree/master/example_standalone), which only
requires Redis and Elasticsearch.

## requirements

Docker with the Compose plugin. The scripts call the v1 binary (`docker-compose`); on a modern Docker
install substitute `docker compose` (space, no hyphen).

## clusters

| Script | Brings up | Compose files |
|---|---|---|
| `start_zookeeper_cluster.sh` | 3 ZooKeeper nodes | `zookeeper/` |
| `start_kafka_cluster.sh` | 3 ZooKeeper nodes + 3 Kafka brokers | `zookeeper/` + `kafka/` |
| `start_spark_cluster.sh` | Spark master + 2 workers + JupyterLab | `spark/` |

Kafka has a hard dependency on ZooKeeper, which is why `start_kafka_cluster.sh` composes both files —
do not start `kafka/docker-compose.yml` on its own.

```shell
bash start_kafka_cluster.sh     # zookeeper + kafka
bash start_spark_cluster.sh     # spark, independent of the above
```

All scripts run in the foreground (`up` without `-d`). Add `-d` to the command inside the script, or
run the compose command yourself, to daemonize.

## ports

### zookeeper

| Node | Client port | Peer / election |
|---|---|---|
| zookeeper-1 | 22181 | 22888 / 23888 |
| zookeeper-2 | 32181 | 32888 / 33888 |
| zookeeper-3 | 42181 | 42888 / 43888 |

Each node has a healthcheck (`echo stat | nc localhost <port>`, every 10s).

### kafka

| Broker | Host port | broker.id |
|---|---|---|
| kafka-1 | 19092 | 1 |
| kafka-2 | 29092 | 2 |
| kafka-3 | 39092 | 3 |

### spark

| Application | URL | Description |
|---|---|---|
| JupyterLab | http://localhost:8888 | notebooks, image `andreper/jupyterlab:3.0.0-spark-3.0.0` |
| Spark Driver | http://localhost:4040 | driver web UI (exposed through the JupyterLab container) |
| Spark Master | http://localhost:8080 | master web UI; submit endpoint is `spark://localhost:7077` |
| Spark Worker I | http://localhost:8081 | 1 core / 512m |
| Spark Worker II | http://localhost:8082 | 1 core / 512m (container port 8081) |

Workers share a `hadoop-distributed-file-system` named volume mounted at `/opt/workspace`, so files
written from JupyterLab are visible to both workers.

## connecting to Kafka from the host

`KAFKA_ADVERTISED_LISTENERS` is set to the **container** hostnames (`PLAINTEXT://kafka-1:19092`).
A client bootstrapping against `localhost:19092` will connect, then be handed `kafka-1:19092` in the
cluster metadata and fail to resolve it. So the host ports alone are not enough for a host-side
producer/consumer such as `rec-server`. Either:

- map the names on the host — add `127.0.0.1 kafka-1 kafka-2 kafka-3` to `/etc/hosts`; or
- run your client inside the same Compose network, where the names resolve natively; or
- change `KAFKA_ADVERTISED_LISTENERS` to `PLAINTEXT://localhost:<host-port>` per broker.

Consuming from inside the cluster (`docker exec`) always works:

```shell
docker exec -it <kafka-container> kafka-topics --bootstrap-server kafka-1:19092 --list
```

`rec-server` writes to the `item`, `user` and `event` topics when started with the `prod` profile
(`server.pushService=pushKafkaService`); its `spring.kafka.bootstrap-servers` defaults to
`localhost:9092` and must be pointed at the brokers above.

## not included

`example_cluster` also lists Hadoop, Hive and Flink among its dependencies. Those are not provided
here — only ZooKeeper, Kafka and Spark.
