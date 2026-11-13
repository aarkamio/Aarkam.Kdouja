#!/usr/bin/env bash
set -e

echo "=== Aarkam Kdouja Linux Installer (v1.0.2) ==="

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_BIN="/usr/local/bin"
DATA_DIR="/var/lib/kdouja"
CONFIG_DIR="/etc/kdouja"

# Ensure target directories exist
mkdir -p "$DATA_DIR" "$CONFIG_DIR"
chmod 0755 "$DATA_DIR"

# Symlink server daemon
if [ -f "$INSTALL_DIR/kdoujad" ]; then
    chmod +x "$INSTALL_DIR/kdoujad"
    ln -sf "$INSTALL_DIR/kdoujad" "$TARGET_BIN/kdoujad"
    echo "[?] Symlinked: $TARGET_BIN/kdoujad -> $INSTALL_DIR/kdoujad"
fi

# Symlink CLI (kdouja) and backward compatibility alias (kdouja-cli)
if [ -f "$INSTALL_DIR/kdouja" ]; then
    chmod +x "$INSTALL_DIR/kdouja"
    ln -sf "$INSTALL_DIR/kdouja" "$TARGET_BIN/kdouja"
    ln -sf "$INSTALL_DIR/kdouja" "$TARGET_BIN/kdouja-cli"
    echo "[?] Symlinked: $TARGET_BIN/kdouja -> $INSTALL_DIR/kdouja"
    echo "[?] Symlinked alias: $TARGET_BIN/kdouja-cli -> $INSTALL_DIR/kdouja"
elif [ -f "$INSTALL_DIR/kdouja-cli" ]; then
    chmod +x "$INSTALL_DIR/kdouja-cli"
    ln -sf "$INSTALL_DIR/kdouja-cli" "$TARGET_BIN/kdouja"
    ln -sf "$INSTALL_DIR/kdouja-cli" "$TARGET_BIN/kdouja-cli"
    echo "[?] Symlinked: $TARGET_BIN/kdouja -> $INSTALL_DIR/kdouja-cli"
fi

# Copy appsettings.json if present and not yet in /etc/kdouja
if [ -f "$INSTALL_DIR/appsettings.json" ] && [ ! -f "$CONFIG_DIR/appsettings.json" ]; then
    cp "$INSTALL_DIR/appsettings.json" "$CONFIG_DIR/appsettings.json"
    echo "[?] Staged default configuration to $CONFIG_DIR/appsettings.json"
fi

echo ""
echo "Aarkam Kdouja v1.0.2 installed successfully."
echo "Execute 'kdouja --help' or 'kdoujad' to begin."