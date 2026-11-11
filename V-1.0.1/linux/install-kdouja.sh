#!/usr/bin/env bash
set -e

echo "=== Aarkam Kdouja Linux Installer (v1.0.1) ==="

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_BIN="/usr/local/bin"
DATA_DIR="/var/lib/kdouja"

mkdir -p "$DATA_DIR"
chmod 0755 "$DATA_DIR"

if [ -f "$INSTALL_DIR/kdoujad" ]; then
    chmod +x "$INSTALL_DIR/kdoujad"
    ln -sf "$INSTALL_DIR/kdoujad" "$TARGET_BIN/kdoujad"
    echo "Symlinked: $TARGET_BIN/kdoujad -> $INSTALL_DIR/kdoujad"
fi

if [ -f "$INSTALL_DIR/kdouja-cli" ]; then
    chmod +x "$INSTALL_DIR/kdouja-cli"
    ln -sf "$INSTALL_DIR/kdouja-cli" "$TARGET_BIN/kdouja-cli"
    echo "Symlinked: $TARGET_BIN/kdouja-cli -> $INSTALL_DIR/kdouja-cli"
fi

echo "Aarkam Kdouja installed successfully."
echo "Execute 'kdouja-cli --help' or 'kdoujad' to begin."
