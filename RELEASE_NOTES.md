# bigdata-platform v0.1.0

Released: 2026-10-05

Development and integration infrastructure. First coordinated OpenRec source release.

## Features

- Standalone Redis, Elasticsearch, Prometheus and Grafana deployment.
- Cluster Kafka/ZooKeeper, HDFS/YARN, Hive, HBase, Spark, Flink and Airflow infrastructure.
- `platform.sh` lifecycle commands with dependency closure and smoke checks.
- Component-owned images/configuration, monitoring exporters, persistent volumes and configurable resource budgets.
- Java 21 Spark 4.0.4 and Flink 2.2.1 engines, with independent JVM versions for storage daemons.

## Installation and compatibility

Use the matching OpenRec distribution and application components. The release versions the infrastructure source/configuration; upstream service image versions remain independent.

The supplied Compose topology is for development and integration. It includes single-point services and sample credentials; it does not provide authenticated production HA. Preserve volumes during routine shutdown. `down -v` deliberately removes data. Build images from this source release; no versioned OCI publication is claimed.

## Validation and known boundaries

See this repository's README for build/test commands and deployment requirements. The coordinated release's [validation record](https://github.com/open-rec/openrec/blob/v0.1.0/release/VALIDATION.md) distinguishes checks executed for this release from historical integration evidence.

This initial release establishes a versioned source baseline. Source archives and checksums are published; external package registries and container registries are not populated by the source-release workflow. Upgrade the complete compatible distribution, retain data/checkpoints/artifacts, and preserve prior component refs for rollback.
