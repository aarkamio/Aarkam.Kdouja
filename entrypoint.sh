#!/bin/bash
set -e

# Resolve CLI binary path
CLI_BIN="/app/kdouja"
if [ ! -f "$CLI_BIN" ]; then
    CLI_BIN="/app/kdouja-cli"
fi

# Route commands dynamically between the daemon (kdoujad) and CLI (kdouja)
case "$1" in
    kdouja|kdouja-cli)
        shift
        exec "$CLI_BIN" "$@"
        ;;
    info|stats|kv|compact|bench|dump-sst|sst|license|repl|shell|interactive|get|put|del|delete|scan|--help|-h|--version|-v|help)
        exec "$CLI_BIN" "$@"
        ;;
    "")
        # Default: Start autonomous Kdouja engine daemon
        exec /app/kdoujad
        ;;
    *)
        exec "$@"
        ;;
esac
