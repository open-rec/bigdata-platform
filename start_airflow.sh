#!/usr/bin/env bash
exec "$(dirname "$0")/platform.sh" up airflow "$@"
