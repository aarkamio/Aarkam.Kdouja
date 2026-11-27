#!/bin/bash
set -e

# Resolve CLI binary path
CLI_BIN="/app/kdouja"
if [ ! -f "$CLI_BIN" ]; then
    CLI_BIN="/app/kdouja-cli"
fi

# Best-effort raise file descriptor limit for high-concurrency SSTables and gRPC streams
ulimit -n 65536 2>/dev/null || true

# Route commands dynamically between the daemon (kdoujad) and CLI (kdouja)
case "$1" in
    kdouja|kdouja-cli)
        shift
        exec "$CLI_BIN" "$@"
        ;;
    info|stats|health|ping|config|verify|check|backup|restore|export|import|pages|kv|compact|bench|dump-sst|sst|license|auth|repl|shell|interactive|get|put|del|delete|scan|--help|-h|--version|-v|help)
        exec "$CLI_BIN" "$@"
        ;;
    "")
        # Preflight storage check: warn if data directory is on ephemeral overlayfs instead of a dedicated volume
        DATA_DIR="${KDOUJA_BASE_DIRECTORY:-/var/lib/kdouja}"
        mkdir -p "$DATA_DIR"
        FS_TYPE="$(df -T "$DATA_DIR" 2>/dev/null | awk 'NR==2 {print $2}' || true)"
        if [ "$FS_TYPE" = "overlay" ]; then
            echo "[Aarkam.Kdouja] WARNING: '$DATA_DIR' is backed by container overlayfs. For maximum Direct I/O performance and durability, mount a dedicated non-OS NVMe/SSD volume (-v /mnt/nvme/kdouja:/var/lib/kdouja)." >&2
        fi
        # Default: Start autonomous Kdouja engine daemon
        exec /app/kdoujad
        ;;
    *)
        exec "$@"
        ;;
esac
