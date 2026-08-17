# bigdata-platform

The infrastructure open-rec's **cluster** mode runs on, as one Docker Compose project:
ZooKeeper, Kafka, HDFS, YARN, Hive, HBase and Spark.

Standalone mode needs none of this — see
[example_standalone](https://github.com/open-rec/example/tree/master/example_standalone), which only
wants Redis and Elasticsearch.

| Component | Role in the platform | Image |
|---|---|---|
| ZooKeeper | coordination for Kafka and HBase | `confluentinc/cp-zookeeper` |
| Kafka | the ingest queue `rec-server` publishes to | `confluentinc/cp-kafka` |
| HDFS | storage layer under Hive, HBase and Spark event logs | `apache/hadoop` |
| YARN | cluster compute for Hive-on-Tez (and Spark, if you prefer it to standalone) | `apache/hadoop` |
| Hive | the warehouse: SQL and a metastore over HDFS, the data source for offline training | built from `apache/hive` |
| HBase | random-access KV store for large-scale point lookups | built from the Apache tarball |
| Spark | batch and structured-streaming compute, Kafka connector included | built from `apache/spark` |

## requirements

- Docker with the Compose plugin (`docker compose`). The v1 `docker-compose` binary also works —
  `platform.sh` detects whichever is present.
- Roughly 16 GB of RAM and 8 cores for the full stack; a single profile needs far less. Sizing knobs
  are at the bottom of `.env`.
- Outbound network on first run: three of the images are built locally and download Hive's JDBC
  driver, the HBase release tarball and Spark's Kafka connector jars.

## quick start

```shell
./platform.sh pull            # fetch third-party images (surfaces a bad tag immediately)
./platform.sh build           # build the hive / hbase / spark images
./platform.sh up all          # or: up kafka / up hive / up hbase / up spark
./platform.sh ps              # wait until services report healthy
./platform.sh smoke           # verify each running component
```

Bring-up is asynchronous. On a cold start the namenode formats itself, Hive creates its metastore
schema and Kafka creates its topics; two or three minutes is normal. `smoke` is how you find out
whether it worked — `up` returning does not mean the platform is ready.

Tear down with `./platform.sh down`, or `./platform.sh down -v` to delete the volumes as well (all
HDFS data, Kafka logs and Hive metadata go with them).

## platform.sh

```
./platform.sh up [component...]     start components plus their dependencies (default: all)
./platform.sh down [-v]             stop everything; -v also deletes volumes
./platform.sh ps                    container state
./platform.sh logs [service...]     follow logs
./platform.sh restart <service...>  restart named services
./platform.sh build [component...]  build the locally-built images
./platform.sh pull                  pre-pull third-party images
./platform.sh init [component...]   re-run the bootstrap one-shots (idempotent)
./platform.sh smoke [component...]  verify whatever is running
./platform.sh shell <target>        zk | kafka | hdfs | hive | hbase | spark
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
| `all` | everything |

Raw Compose works too, but you must name every profile yourself:

```shell
docker compose --profile zookeeper --profile hdfs --profile hbase up -d
```

`./platform.sh shell hive` drops into beeline, `shell hbase` into the HBase shell, `shell spark` into
`spark-sql`, `shell zk` into `zookeeper-shell`.

The three `start_*_cluster.sh` scripts still exist because the
[example_cluster](https://github.com/open-rec/example/tree/master/example_cluster) walkthrough
references them by name. They are one-line shims over `platform.sh up`, and unlike the old versions
they start in the **background**.

## ports

Host ports for ZooKeeper, Kafka and Spark are unchanged from the previous layout. Everything avoids
the ports the rest of the workspace uses: 13579 (`rec-server`), 8000 (`rank-engine`), 6379 (Redis),
9200 (Elasticsearch).

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
| hbase-master | 16000 | http://localhost:16010 |
| hbase-regionserver-1 / -2 | 16020 / 16021 | http://localhost:16030 , :16031 |
| hbase-thrift | 9090 | http://localhost:9095 |
| spark-master | 7077 | http://localhost:8080 |
| spark-worker-1 / -2 | — | http://localhost:8081 , :8082 |
| spark-history | — | http://localhost:18080 |
| jupyterlab | — | http://localhost:8888 (no token), driver UI :4040 |

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

## component notes

### HDFS

Two datanodes, replication 2 (`HDFS_REPLICATION` in `.env`). Shared settings live in
`hadoop/hadoop.env`, which the `apache/hadoop` image turns into XML: an env var named
`CORE-SITE.XML_fs.defaultFS` becomes the `fs.defaultFS` property in `core-site.xml`.

Two things worth knowing:

- **The volume is mounted at `/opt/hadoop/dfs`, one level above the name dir.** The image formats the
  namenode only when `ENSURE_NAMENODE_DIR` does not exist. Mounting a volume straight onto the name
  dir would make it exist-but-empty on first boot and the namenode would refuse to start.
- **`dfs.permissions.enabled=false`.** File ownership across the Hive, HBase and Spark containers is
  more trouble than it is worth for a lab. Turn it back on in `hadoop/hadoop.env` before pointing real
  users at this.

The `hdfs-init` one-shot waits until HDFS actually accepts writes and then creates
`/user/hive/warehouse`, `/spark-logs`, `/hbase`, `/tmp` and `/user/spark`. Everything downstream
depends on *that* completing rather than on the namenode being up, because "namenode listening" and
"HDFS usable" are not the same thing.

### Hive

Metadata in Postgres, warehouse on HDFS at `/user/hive/warehouse`. `hive/conf/hive-site.xml` is
injected through the image's `HIVE_CUSTOM_CONF_DIR` mechanism, and `hive-schema-init` runs
`schematool -initOrUpgradeSchema` (idempotent, so it is safe on every boot).

The JDBC credentials appear in two places — `HIVE_DB_*` in `.env`, which creates the Postgres user,
and `hive/conf/hive-site.xml`, which connects with it. XML cannot read `.env`; if you change one,
change the other.

**Hive 4 removed the MapReduce engine**, so anything that needs a real job runs on Tez over YARN —
which is why `up hive` starts the `yarn` profile too. DDL, metadata operations and simple fetches do
not need it. For heavy SQL over the warehouse, Spark SQL is the better tool here.

### HBase

Fully distributed: regions on HDFS under `/hbase`, coordination on the ZooKeeper ensemble, master plus
two regionservers plus a Thrift gateway. Apache publishes no official HBase image, so
`hbase/Dockerfile` unpacks the release tarball onto a JRE base; the role is selected at runtime with
`HBASE_ROLE` (`master`, `regionserver`, `thrift`, `rest`) by `hbase/entrypoint.sh`.

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

## data and volumes

Everything stateful is in named volumes: `namenode-data`, `datanode-data-{1,2}`,
`kafka-data-{1,2,3}`, `zk-data*`, `hive-pgdata`, `hive-libs`, `spark-workspace`. `down` keeps them;
`down -v` destroys them.

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
- **Not a production topology.** Single namenode, single HBase master, single resourcemanager, no HA,
  no auth, no TLS, HDFS permission checks off, JupyterLab with an empty token. It is a development and
  simulation platform.
- **`hive.execution.engine=tez` depends on the Tez setup inside the Hive image.** If Tez jobs fail to
  launch, metadata and DDL still work; use Spark SQL for compute, or check
  `./platform.sh logs hiveserver2` for the `tez.lib.uris` it resolved.
- **Flink is not included.** `example_cluster` lists it as an alternative stream processor; nothing in
  open-rec targets it today.
- **`data-processor` is still unpublished.** This repo provides the infrastructure that the
  Kafka → warehouse/KV pipeline would run on, not the pipeline itself: no Hive DDL, no Spark jobs and
  no HBase table definitions ship here.
