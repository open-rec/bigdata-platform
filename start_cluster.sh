#!/usr/bin/env bash
# Start the complete distributed deployment mode and all of its dependencies.
exec "$(dirname "$0")/platform.sh" up cluster "$@"
