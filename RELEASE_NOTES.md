# bigdata-platform v0.2.0

Released: 2026-10-18

Part of the coordinated OpenRec v0.2.0 source release.

## Changes since v0.1.0

- Add an optional configurable CUDA 12.9 vLLM embedding service.
- Support reuse of local images for regression runs and document versioned Kafka mutations.

## Installation and compatibility

Standalone and cluster retain distinct dependency closures. Use platform.sh for lifecycle operations. vLLM is optional and must match the title-vector encoder and dimensions. Preserve persistent storage and replace sample credentials for deployment.

See the [distribution upgrade and rollback instructions](https://github.com/open-rec/openrec/blob/v0.2.0/RELEASE_NOTES.md) for the complete compatible component set and persisted configuration migrations.

## Validation and publication

The [validation record](https://github.com/open-rec/openrec/blob/v0.2.0/release/VALIDATION.md) distinguishes release checks from maintainer-reported prior CI and integration results. GitHub Actions publishes source archives and SHA-256 checksums; Maven Central, PyPI and versioned container registries are not populated by this workflow.
