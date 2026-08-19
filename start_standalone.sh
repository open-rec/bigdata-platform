#!/usr/bin/env bash
# Start the complete small-data deployment mode: Redis + Elasticsearch.
exec "$(dirname "$0")/platform.sh" up standalone "$@"
