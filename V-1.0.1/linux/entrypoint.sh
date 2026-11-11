#!/bin/bash
set -e

# Route commands dynamically between the daemon (kdoujad) and CLI (kdouja-cli)
if [ "$1" = "kdouja-cli" ]; then
    shift
    exec /app/kdouja-cli "$@"
elif [ "$1" = "info" ] || [ "$1" = "kv" ] || [ "$1" = "compact" ] || [ "$1" = "bench" ] || [ "$1" = "dump-sst" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    exec /app/kdouja-cli "$@"
elif [ -n "$1" ]; then
    exec "$@"
else
    # Default: Start autonomous Kdouja engine daemon
    exec /app/kdoujad
fi
