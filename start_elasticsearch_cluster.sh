#!/usr/bin/env bash
# Start the elasticsearch component and everything it needs.
# Starts: the Elasticsearch vector index (single node, TLS + auth).
#
# A shim over platform.sh so the dependency closure stays defined in one place.
# Runs in the background; follow the output with `./platform.sh logs`.
exec "$(dirname "$0")/platform.sh" up elasticsearch "$@"
