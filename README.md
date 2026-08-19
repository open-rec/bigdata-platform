# bigdata-platform

The infrastructure open-rec runs on, as one Docker Compose project with two peer deployment modes:

| Mode | Components | Intended use |
|---|---|---|
| `standalone` | Redis + Elasticsearch | small data, one machine, direct ingestion from `rec-server` |
| `cluster` | ZooKeeper, Kafka, HDFS, YARN, Hive, HBase, Spark, Redis, Elasticsearch | distributed ingestion, storage, and offline processing |

Standalone is the complete small-data mode described by
[example_standalone](https://github.com/open-rec/example/tree/master/example_standalone), not a
partially started Cluster. Both modes share the serving-store contracts, images, and tooling.

**Each component is its own image, built from its own Dockerfile with its configuration baked in.**
`docker-compose.yml` only orchestrates them, so any component can equally be deployed on its own —
`docker run openrec/hadoop:3.3.6 namenode` — or dropped into another compose file or a k8s manifest.
Each image takes a **role** as its argument (`namenode`, `datanode`, `broker`, `master`, `worker`,
`metastore`, ...); the header of every Dockerfile shows standalone usage.

| Component | Role in the platform | Image (built from) | Roles |
|---|---|---|---|
| ZooKeeper | coordination for Kafka and HBase | `openrec/zookeeper` (Apache tarball) | `server`, `cli` |
| Kafka | the ingest queue `rec-server` publishes to | `openrec/kafka` (Apache tarball) | `broker`, `init` |
| HDFS + YARN | storage and compute layer under Hive, HBase and Spark | `openrec/hadoop` (`apache/hadoop`) | `namenode`, `datanode`, `resourcemanager`, `nodemanager`, `historyserver`, `init` |
| Hive | the warehouse: SQL and a metastore over HDFS, the data source for offline training | `openrec/hive` (`apache/hive`) | `metastore`, `hiveserver2`, `schematool`, `publish-libs`, `beeline` |
| HBase | random-access KV store for large-scale point lookups | `openrec/hbase` (Apache tarball) | `master`, `regionserver`, `thrift`, `rest` |
| Spark | batch and structured-streaming compute, Kafka connector included | `openrec/spark` (`apache/spark`) | `master`, `worker`, `history`, `jupyter`, `submit`, `sql` |
| Redis | serving-layer KV store: recall tables, user/item rows, events | `openrec/redis` (`redis`) | — |
| Elasticsearch | serving-layer vector index for embedding recall | `openrec/elasticsearch` (`docker.elastic.co`) | `server`, `certs` |

Postgres, the Hive metastore database, is the one component used as a stock upstream image.

## requirements

- Docker with the Compose plugin (`docker compose`). The v1 `docker-compose` binary also works —
  `platform.sh` detects whichever is present.
- Roughly 20 GB of RAM and 8 cores for the full stack; a single profile needs far less. Sizing knobs
  are at the bottom of `.env`.
- `vm.max_map_count >= 262144` on the docker host, or Elasticsearch will refuse to start:
  `sudo sysctl -w vm.max_map_count=262144`.
- Outbound network on first run: every image is built locally, pulling the upstream bases plus the
  ZooKeeper, Kafka and HBase release tarballs from the configured mainland mirror, Hive's Postgres JDBC driver
  and Spark's Kafka connector jars from Maven Central.

## quick start

Choose one mode explicitly. Without an argument, `up`, `build`, and `smoke` default to Standalone.

```shell
./platform.sh build standalone
./platform.sh up standalone
./platform.sh smoke standalone

./platform.sh build cluster
./platform.sh up cluster
./platform.sh smoke cluster
```

Bring-up is asynchronous. On a cold start the namenode formats itself, Hive creates its metastore
schema and Kafka creates its topics; two or three minutes is normal. `smoke` is how you find out
whether it worked — `up` returning does not mean the platform is ready.

Stop only the selected mode with `./platform.sh down standalone` or `./platform.sh down cluster`.
`./platform.sh down -v` is deliberately global: it destroys both modes and all persisted data.

## platform.sh

```
./platform.sh up [mode|component...] start a mode or component closure (default: standalone)
./platform.sh down [mode|component...] stop a mode (default: standalone)
./platform.sh down -v              destroy both modes and delete all volumes
./platform.sh ps                    container state
./platform.sh logs [service...]     follow logs
./platform.sh restart <service...>  restart named services
./platform.sh build [mode|component...] build images (default: standalone)
./platform.sh pull                  pre-pull third-party images
./platform.sh init [mode|component...] re-run bootstrap one-shots (default: standalone)
./platform.sh smoke [mode|component...] verify a mode (default: standalone)
./platform.sh shell <target>        zk | kafka | hdfs | hive | hbase | spark | redis | es
./platform.sh config                dump the resolved compose config
```

The point of the wrapper is the dependency closure — Compose will not work out that a Hive warehouse
needs HDFS:

| `up <component>` | actually starts |
|---|---|
| `zookeeper` | zookeeper |
| `kafka` | zookeeper, kafka |
| `hdfs` | hdfs |
| `yarn` | hdfs, yarn |
| `hive` | hdfs, yarn, hive |
| `hbase` | zookeeper, hdfs, hbase |
| `spark` | hdfs, spark |
| `redis` | redis |
| `elasticsearch` | elasticsearch |
| `standalone` | redis, elasticsearch |
| `cluster` | all components |
| `storage` | compatibility alias for `standalone` |
| `all` | compatibility alias for `cluster` |

Raw Compose works too, but you must name every profile yourself:

```shell
docker compose --profile zookeeper --profile hdfs --profile hbase up -d
```

`./platform.sh shell hive` drops into beeline, `shell hbase` into the HBase shell, `shell spark` into
`spark-sql`, `shell redis` into `redis-cli`, `shell zk` into `zookeeper-shell`.

### start scripts

Mode-level scripts are the preferred entry points:

| Script | Brings up |
|---|---|
| `start_standalone.sh` | complete Standalone mode: Redis + Elasticsearch |
| `start_cluster.sh` | complete Cluster mode: all infrastructure components |

One per component, for starting a single piece of the platform without remembering its dependencies:

| Script | Brings up |
|---|---|
| `start_zookeeper_cluster.sh` | the 3-node ensemble |
| `start_kafka_cluster.sh` | ZooKeeper + 3 brokers + topic bootstrap |
| `start_hadoop_cluster.sh` | namenode + 2 datanodes + HDFS bootstrap |
| `start_yarn_cluster.sh` | HDFS + resourcemanager + 2 nodemanagers |
| `start_hive_cluster.sh` | HDFS + YARN + metastore db, metastore, HiveServer2 |
| `start_hbase_cluster.sh` | ZooKeeper + HDFS + master, 2 regionservers, Thrift |
| `start_spark_cluster.sh` | HDFS + master, 2 workers, history server, JupyterLab |
| `start_redis_cluster.sh` | Redis |
| `start_elasticsearch_cluster.sh` | Elasticsearch |

They are one-line shims over `platform.sh up <mode|component>`, so mode membership and dependency
closures stay defined in exactly one place. Extra arguments are passed through. Older scripts keep their historical names
because the [example_cluster](https://github.com/open-rec/example/tree/master/example_cluster)
walkthrough references them; unlike the versions it describes, they start in the **background**.

## deploying a component on its own

Because the configuration is inside the images rather than in this compose file, a component runs
standalone with nothing from this repo but its own directory:

```shell
docker build -t openrec/hadoop:3.3.6 ./hadoop
docker network create bigdata

docker run -d --network bigdata --name namenode   -p 9870:9870 -p 8020:8020 openrec/hadoop:3.3.6 namenode
docker run -d --network bigdata --name datanode-1                          openrec/hadoop:3.3.6 datanode
docker run --rm --network bigdata                                          openrec/hadoop:3.3.6 init
```

The same pattern applies to the rest — the role is the container's argument:

```shell
docker run -d --name zookeeper-1 -p 2181:2181 \
  -e ZOO_MY_ID=1 -e ZOO_SERVERS="server.1=zookeeper-1:2888:3888;2181" \
  openrec/zookeeper:3.9.2 server

docker run -d --name kafka-1 -p 9092:9092 \
  -e KAFKA_BROKER_ID=1 -e KAFKA_ZOOKEEPER_CONNECT=zookeeper-1:2181 \
  -e KAFKA_LISTENERS=PLAINTEXT://0.0.0.0:9092 \
  -e KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://localhost:9092 \
  openrec/kafka:3.7.1 broker

docker run -d --name elasticsearch -p 9200:9200 \
  -e ELASTIC_PASSWORD=openrec-es-password openrec/elasticsearch:8.5.0 server
```

Where the configuration for each image lives:

| Image | Config it bakes in | Runtime knobs |
|---|---|---|
| `openrec/zookeeper` | `zoo.cfg`, rendered by `entrypoint.sh` | `ZOO_MY_ID`, `ZOO_SERVERS`, `ZOO_*` |
| `openrec/kafka` | `server.properties`, rendered by `entrypoint.sh` | every `KAFKA_*` becomes a property |
| `openrec/hadoop` | `hadoop/conf/{core,hdfs,yarn,mapred}-site.xml` | role argument |
| `openrec/hive` | `hive/conf/hive-site.xml` | role argument, `HIVE_DB_*` |
| `openrec/hbase` | `hbase/conf/hbase-site.xml`, `hbase-env.sh` | `HBASE_ROLE` or role argument, `HBASE_HEAPSIZE` |
| `openrec/spark` | `spark/conf/spark-defaults.conf` | role argument, `SPARK_*` |
| `openrec/redis` | `redis/redis.conf` | extra `redis-server` flags |
| `openrec/elasticsearch` | `elasticsearch/conf/elasticsearch.yml` | `ELASTIC_PASSWORD`, `ES_JAVA_OPTS` |

The compose file bind-mounts `spark-defaults.conf`, `hive-site.xml`, and the Hadoop XML files needed
by Hive's HDFS/Tez clients. Those can be edited and picked up with a restart instead of a rebuild.

## ports

Several host ports are shifted to avoid common local conflicts. Container-network ports remain the
upstream defaults. Configure host-side clients with the host ports below; nothing here collides with
the two open-rec services themselves: 13579 (`rec-server`) and 8000 (`rank-engine`).

| Service | Host port | Web UI |
|---|---|---|
| zookeeper-1 / -2 / -3 | 22181 / 32181 / 42181 | — |
| kafka-1 / -2 / -3 | 19092 / 29092 / 39092 | — |
| namenode | 8020 (RPC) | http://localhost:9870 |
| datanode-1 / -2 | — | http://localhost:9864 , :9865 |
| resourcemanager | — | http://localhost:8088 |
| nodemanager-1 / -2 | — | http://localhost:8042 , :8043 |
| hive-metastore-db (postgres) | 15432 | — |
| hive-metastore | 9083 | — |
| hiveserver2 | 10000 (JDBC) | http://localhost:10002 |
| hbase-master | 16001 | http://localhost:16010 |
| hbase-regionserver-1 / -2 | 16020 / 16021 | http://localhost:16030 , :16031 |
| hbase-thrift | 9090 | http://localhost:9095 |
| spark-master | 7077 | http://localhost:8083 |
| spark-worker-1 / -2 | — | http://localhost:8084 , :8086 |
| spark-history | — | http://localhost:18080 |
| jupyterlab | — | http://localhost:8889 (no token), driver UI :4040 |
| redis | 6380 | — |
| elasticsearch | 9200 (https) | https://localhost:9200 (basic auth) |

All of these are set in `.env`; change them there, not in `docker-compose.yml`.

## endpoints

Addresses differ depending on which side of the Compose network you are on. This trips people up
constantly, so both are spelled out:

| | from inside the network | from the docker host |
|---|---|---|
| Kafka | `kafka-1:9092,kafka-2:9092,kafka-3:9092` | `localhost:19092,localhost:29092,localhost:39092` |
| ZooKeeper | `zookeeper-1:2181,zookeeper-2:2181,zookeeper-3:2181` | `localhost:22181,localhost:32181,localhost:42181` |
| HDFS | `hdfs://namenode:8020` | `hdfs://localhost:8020` |
| Hive metastore | `thrift://hive-metastore:9083` | `thrift://localhost:9083` |
| HiveServer2 | `jdbc:hive2://hiveserver2:10000` | `jdbc:hive2://localhost:10000` |
| HBase | ZK quorum above, znode `/hbase` | Thrift on `localhost:9090` |
| Spark master | `spark://spark-master:7077` | `spark://localhost:7077` |
| Redis | `redis:6379` | `localhost:6380` |
| Elasticsearch | `https://elasticsearch:9200` | `https://localhost:9200` |

**Kafka no longer needs an `/etc/hosts` workaround.** Each broker advertises two listeners — the
container name on the internal one and `localhost:<host port>` on the external one — so a producer on
the host connects, gets handed `localhost:19092` in the cluster metadata, and resolves it correctly.
Earlier versions of this repo advertised only container hostnames, which is why the old README told
you to map `kafka-1`, `kafka-2` and `kafka-3` in `/etc/hosts`. That step is obsolete.

Note that the three ZooKeeper nodes now all listen on **2181** inside the network (only the published
host ports differ). HBase composes its connect string from `hbase.zookeeper.quorum` plus a single
`clientPort`, so per-node client ports could not be expressed there.

## connecting the open-rec services

`rec-server` in `prod` mode publishes pushed items, users and events to Kafka
(`server.pushService=pushKafkaService`). Point it at the brokers in
`rec-server/server/src/main/resources/application-prod.properties`:

```properties
spring.kafka.bootstrap-servers=localhost:19092,localhost:29092,localhost:39092
```

The topics it writes — `item`, `user`, `event` — are created by the `kafka-init` one-shot with 12
partitions and replication factor 3 (`KAFKA_TOPICS` in `.env`). Auto-creation is deliberately off, so
a typo in a topic name fails loudly instead of silently creating a single-replica topic.

Watch the ingest path:

```shell
docker exec -it kafka-1 kafka-console-consumer \
  --bootstrap-server kafka-1:9092 --topic event --from-beginning
```

The payloads are Gson-serialised field-for-field from `rec-server`'s `Item` / `User` / `Event` model
classes, so the JSON keys are camelCase (`userId`, `itemId`, `pubTime`, `isLogin`, `extFields`).

If you run a consumer or a Spark job **inside** this network, use the internal broker addresses; join
the network with `--network openrec-bigdata`.

For the serving layer, point host-side clients at Redis's shifted host port and make the
Elasticsearch password agree:

```properties
redis.hostName=127.0.0.1
redis.port=6380
es.host=127.0.0.1
es.port=9200
es.user=elastic
es.password=openrec-es-password   # must equal ELASTIC_PASSWORD in .env
```

The Standalone order is `up standalone` -> run `example/init` -> start `rec-server`. Configure and
start `rank-engine` only when the graph's rank node is enabled; its Redis endpoint is
`localhost:6380`.

Seed the serving layer with the standalone loader:

```shell
cd ../example
java -cp init/target/rec-example-init-1.0-SNAPSHOT-jar-with-dependencies.jar \
  com.openrec.example.InitStandalone 127.0.0.1 6380 127.0.0.1 9200 elastic 'openrec-es-password'
```

## component notes

### HDFS

Two datanodes, replication 2. Configuration is four ordinary Hadoop XML files under `hadoop/conf/`,
baked into `openrec/hadoop` — the upstream image's `CORE-SITE.XML_<property>` environment-variable
translation is not used, so what you read in those files is exactly what the daemons load.

Two things worth knowing:

- **`dfs.replication` lives in `hadoop/conf/hdfs-site.xml`, not `.env`.** It has to agree with the
  number of datanode containers, which is a compose-level decision — the two are edited together, so
  keeping the value next to the other HDFS settings beats a knob that can silently disagree.
- **`dfs.permissions.enabled=false`.** File ownership across the Hive, HBase and Spark containers is
  more trouble than it is worth for a lab. Turn it back on in `hadoop/conf/hdfs-site.xml` before
  pointing real users at this.

The namenode formats itself on first start by checking for `current/VERSION` in its name dir, so the
volume mounts straight onto that directory and a re-created container never reformats live data.

The `hdfs-init` one-shot waits until HDFS actually accepts writes and then creates
`/user/hive/warehouse`, `/spark-logs`, `/hbase`, `/tmp` and `/user/spark`. Everything downstream
depends on *that* completing rather than on the namenode being up, because "namenode listening" and
"HDFS usable" are not the same thing.

### Hive

Metadata in Postgres, warehouse on HDFS at `/user/hive/warehouse`. `hive/conf/hive-site.xml` is baked
into `openrec/hive` (and bind-mounted over in compose, so edits need only a restart). The roles are
plain Hive commands — `hive --service metastore`, `hive --service hiveserver2`, `schematool` — rather
than the upstream image's `SERVICE_NAME` / `IS_RESUME` / `HIVE_CUSTOM_CONF_DIR` indirection, so the
container behaves the same however it is launched. `hive-schema-init` runs
`schematool -initOrUpgradeSchema`, which is idempotent and therefore safe on every boot.

The JDBC credentials appear in two places — `HIVE_DB_*` in `.env`, which creates the Postgres user,
and `hive/conf/hive-site.xml`, which connects with it. XML cannot read `.env`; if you change one,
change the other.

**Hive 4 removed the MapReduce engine**, so anything that needs a real job runs on Tez over YARN —
which is why `up hive` starts the `yarn` profile too. DDL, metadata operations and simple fetches do
not need it. For heavy SQL over the warehouse, Spark SQL is the better tool here.

### HBase

Fully distributed: regions on HDFS under `/hbase`, coordination on the ZooKeeper ensemble, master plus
two regionservers plus a Thrift gateway. Apache publishes no official HBase image, so
`hbase/Dockerfile` unpacks the release tarball onto a JRE base; the role (`master`, `regionserver`,
`thrift`, `rest`) is the container's argument, handled by `hbase/entrypoint.sh`.

The Thrift gateway on 9090 is the practical entry point for Python — `happybase` is installed in the
Spark image for exactly this.

```shell
./platform.sh shell hbase
hbase> create 'demo', 'cf'
hbase> put 'demo', 'row1', 'cf:a', 'v1'
hbase> scan 'demo'
```

### Spark

A standalone master with two workers, a history server reading `/spark-logs` on HDFS, and JupyterLab.
The image bakes in `spark-sql-kafka-0-10` and its transitive jars, so structured streaming against the
platform's brokers needs no `--packages` at submit time.

`spark/conf/spark-defaults.conf` is bind-mounted, not baked in — edit it and restart the Spark
services, no rebuild:

```shell
./platform.sh restart spark-master spark-worker-1 spark-worker-2 spark-history jupyterlab
```

**Hive integration is opt-in.** Spark 3.5 embeds a Hive 2.3.9 metastore client, which does not
reliably talk to a Hive 4 metastore, so the Hive block in `spark-defaults.conf` ships commented out.
Once the `hive` profile is up, uncomment it and restart: the `hive-libs-init` one-shot publishes Hive's
own jars into the `hive-libs` volume (mounted read-only at `/opt/hive-libs`) and
`spark.sql.hive.metastore.jars.path` points Spark at them.

Submit a job:

```shell
docker exec -it spark-master /opt/spark/bin/spark-submit \
  --master spark://spark-master:7077 /opt/workspace/your_job.py
```

`/opt/workspace` is a shared volume visible to both workers and JupyterLab.

### Redis

Single node on 6379, **no password**, AOF plus RDB persistence, config in `redis/redis.conf`
(bind-mounted, so edits need only `./platform.sh restart redis`). `maxmemory` and
`maxmemory-policy` come from `.env` as command-line overrides.

No password is a compatibility requirement, not laziness: `rec-server`'s `RedisConfig`,
`example/init`'s `RedisUtil` and `rank-engine`'s client all connect without credentials, so a
`requirepass` here would break all three. Same story for clustering — see the caveats.

This is the store `example/init` seeds and every recommendation request reads. Key layout is
`recall-engine/redis/design.md`:

```shell
./platform.sh shell redis
redis> keys item:*
redis> zrange i2i:{item_1}:scene_0 0 -1 withscores
```

### Elasticsearch

Single node on 9200 holding the per-scene vector index `EmbeddingNode` kNN-searches
(`{scene}-item-vector-index`, `recall-engine/es/design.md`).

**TLS and auth are on**, because the clients demand it: `EsConfig` (rec-server) and `EsUtil`
(example/init) both hardcode the `https` scheme and always send basic auth. They also call
`withUnsafeTrustMaterial()`, so a self-signed certificate is fine and the CA never has to leave the
container.

The image generates that CA and node certificate itself, in its entrypoint, on first start — no
separate init container, which is what keeps a bare `docker run openrec/elasticsearch server`
self-sufficient. It skips generation when the certs are already in the `elastic-certs` volume. All
the settings are in `elasticsearch/conf/elasticsearch.yml`; do not also pass them as environment
variables, because the image turns env vars into `-E` overrides and a setting given twice stops the
node from starting.

The password is `ELASTIC_PASSWORD` in `.env` (default `openrec-es-password`). Unlike a host install
of Elasticsearch 8, nothing is auto-generated and printed once — you set it, so there is nothing to
recover.

```shell
curl -k -u elastic:openrec-es-password https://localhost:9200/_cluster/health?pretty
curl -k -u elastic:openrec-es-password https://localhost:9200/_cat/indices?v
```

## data and volumes

Everything stateful is in named volumes: `namenode-data`, `datanode-data-{1,2}`,
`kafka-data-{1,2,3}`, `zk-data*`, `hive-pgdata`, `hive-libs`, `spark-workspace`, `redis-data`,
`elastic-data` and `elastic-certs`. `down` keeps them; `down -v` destroys them.

Deleting `elastic-certs` is safe — the elasticsearch image regenerates the CA and node certificate on
the next start. Deleting `redis-data` means re-running `example/init` to reseed the serving layer.

To reset a single component, remove its volumes explicitly, e.g. for HDFS:

```shell
./platform.sh down
docker volume rm openrec-bigdata_namenode-data \
  openrec-bigdata_datanode-data-1 openrec-bigdata_datanode-data-2
```

## caveats

- **This stack has not been run end to end in the environment it was written in** (no Docker there).
  The compose file, config XML and scripts are statically validated; the image tags and container
  paths are not. Run `./platform.sh pull` and `./platform.sh build` first — that is where a wrong tag
  or a moved download URL shows up, and every version is pinned in one place (`.env`) so bumping is a
  one-line change.
- **Not a production topology.** Single namenode, single HBase master, single resourcemanager, no HA.
  Elasticsearch is the only component with TLS and authentication (because its clients insist);
  Kafka, HDFS, Hive, HBase and Redis all speak plaintext with no auth, HDFS permission checks are off
  and JupyterLab has an empty token. It is a development and simulation platform.
- **First build is slow.** Eight images, three of them unpacking Apache release tarballs and two
  downloading jars — expect a few GB of downloads and several minutes. `./platform.sh build <component>`
  builds just the one you need.
- **`hive.execution.engine=tez` depends on the Tez setup inside the Hive image.** If Tez jobs fail to
  launch, metadata and DDL still work; use Spark SQL for compute, or check
  `./platform.sh logs hiveserver2` for the `tez.lib.uris` it resolved.
- **Redis is a single node, and cannot simply be made a cluster.** The key layout wraps ids in `{}`
  hash tags so it *would* shard cleanly (see `recall-engine/redis/design.md`), but `rec-server`'s
  `RedisConfig` builds a plain `JedisConnectionFactory` and `rank-engine` uses `redis.Redis` —
  neither follows `MOVED` redirects. Redis Cluster needs a client change in those two repos first.
- **Elasticsearch is a single node** (`discovery.type=single-node`) with a self-signed certificate.
  Scaling to a real cluster means issuing certs for each node from the same CA and dropping the
  single-node discovery setting; `elasticsearch/entrypoint.sh` and `elasticsearch/conf/elasticsearch.yml`
  are the places to extend.
- **No Kibana.** Query Elasticsearch with `curl -k -u elastic:<password>` or from the client code.
- **Flink is not included.** `example_cluster` lists it as an alternative stream processor; nothing in
  open-rec targets it today.
- **`data-processor` is still unpublished.** This repo provides the infrastructure that the
  Kafka → warehouse/KV pipeline would run on, not the pipeline itself: no Hive DDL, no Spark jobs and
  no HBase table definitions ship here.
