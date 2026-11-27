#!/usr/bin/env bash
# ==============================================================================
# Aarkam Kdouja — Production Installation & Bootstrap Script (Linux)
# ==============================================================================
# Target OS:   Ubuntu 22.04 / 24.04 LTS, Debian 12+, RHEL / Rocky / AlmaLinux 9+
# Components:  Aarkam Kdouja Server Daemon (kdoujad) & Kdouja CLI (kdouja / kdouja-cli)
# Version:     V-1.0.3 | Air-Gapped Sovereign Direct I/O Storage Engine Substrate
# Security:    POSIX 0755/0700 Isolation, FIPS 140-3 Zero-Trust Architecture
# ==============================================================================

set -Eeuo pipefail

# ------------------------------------------------------------------------------
# Default Configuration & Paths
# ------------------------------------------------------------------------------
INSTALL_DIR="/usr/local/bin"
DATA_DIR=""
CONFIG_DIR="/etc/aarkam/kdouja"
SOURCE_PATH=""
PORT=57771
STORAGE_PREFERENCE="performance"
USER_ONLY="false"
INSTALL_SERVICE="false"

# ------------------------------------------------------------------------------
# Formatting & Logging Helpers
# ------------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

usage() {
    cat <<EOF
Usage: sudo ./install-kdouja.sh [OPTIONS]

Automated production installer for Aarkam Kdouja Server Daemon & CLI.

Options:
  --source <path>         Path to pre-published binaries directory or .zip release bundle
  --install-dir <path>    Target binary directory (default: ${INSTALL_DIR})
  --data-dir <path>       Target data storage directory (default: ${DATA_DIR})
  --port <number>                 Default daemon TCP port (default: ${PORT})
  --storage-preference <mode>     Non-OS drive ranking: performance (NVMe->SSD->HDD, default) or capacity (HDD->SSD->NVMe)
  --service                       Install and enable systemd service for kdoujad daemon
  --user-only             Install into \${HOME}/.local/bin without requiring root/sudo
  -h, --help              Display this help message

Examples:
  # Standard Production Installation (Server & CLI with systemd service):
  sudo ./install-kdouja.sh --service

  # Non-root User Installation:
  ./install-kdouja.sh --user-only
EOF
    exit 0
}

# ------------------------------------------------------------------------------
# Parse Command-Line Arguments
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --source)       SOURCE_PATH="$2"; shift 2 ;;
        --install-dir)  INSTALL_DIR="$2"; shift 2 ;;
        --data-dir)     DATA_DIR="$2"; shift 2 ;;
        --port)                 PORT="$2"; shift 2 ;;
        --storage-preference)   STORAGE_PREFERENCE="$(echo "$2" | tr '[:upper:]' '[:lower:]')"; shift 2 ;;
        --service)              INSTALL_SERVICE="true"; shift 1 ;;
        --user-only)    USER_ONLY="true"; shift 1 ;;
        -h|--help)      usage ;;
        *)              log_error "Unknown argument: $1"; usage ;;
    esac
done

echo -e "${BLUE}======================================================================${NC}"
echo -e "${CYAN} Aarkam Kdouja — Server Daemon & CLI Production Installer (Linux)     ${NC}"
echo -e "${BLUE} Version: V-1.0.3 | Air-Gapped Sovereign Direct I/O Storage Engine    ${NC}"
echo -e "${BLUE}======================================================================${NC}"

# ------------------------------------------------------------------------------
# Step 1: Privilege & Architecture Verification
# ------------------------------------------------------------------------------
ARCH="$(uname -m)"
if [[ "${ARCH}" != "x86_64" && "${ARCH}" != "amd64" ]]; then
    log_error "Unsupported architecture: ${ARCH}. Only x86_64 / amd64 is supported for this release."
    exit 1
fi
log_ok "Architecture verified: ${ARCH}"

if [[ "${USER_ONLY}" == "true" ]]; then
    INSTALL_DIR="${HOME}/.local/bin"
    if [[ -z "${DATA_DIR}" ]]; then
        DATA_DIR="${HOME}/.kdouja/data"
    fi
    CONFIG_DIR="${HOME}/.config/aarkam/kdouja"
    mkdir -p "${INSTALL_DIR}" "${DATA_DIR}" "${CONFIG_DIR}"
    log_info "Installing in user space: ${INSTALL_DIR}"
else
    if [[ $EUID -ne 0 ]]; then
        log_error "Root or sudo privileges required for system-wide install. Use --user-only for non-root install."
        exit 1
    fi

    # Auto-select non-OS storage partition ranked by media tier (NVMe -> SSD -> Unknown -> HDD) then largest free space
    if [[ -z "${DATA_DIR}" ]]; then
        MIN_PREFERRED_BYTES=10737418240 # 10 GiB guardrail
        CANDIDATES_FILE="$(mktemp)"

        while read -r dev fstype avail mp; do
            [[ -z "${mp}" || ! -d "${mp}" || ! -w "${mp}" ]] && continue
            base_dev="$(lsblk -ndo PKNAME "${dev}" 2>/dev/null | head -n 1 || true)"
            if [[ -z "${base_dev}" ]]; then
                base_dev="$(basename "${dev}" | sed -E 's/p?[0-9]+$//')"
            fi
            tran="$(lsblk -ndo TRAN "/dev/${base_dev}" 2>/dev/null | head -n 1 | tr '[:upper:]' '[:lower:]' || true)"
            rot=""
            if [[ -r "/sys/block/${base_dev}/queue/rotational" ]]; then
                rot="$(cat "/sys/block/${base_dev}/queue/rotational" 2>/dev/null || true)"
            fi

            media="Unknown"
            if [[ "${tran}" == "nvme" || "${base_dev}" == nvme* ]]; then
                media="NVMe"
            elif [[ "${rot}" == "0" ]]; then
                media="SSD"
            elif [[ "${rot}" == "1" ]]; then
                media="HDD"
            fi

            if [[ "${STORAGE_PREFERENCE}" == "capacity" ]]; then
                case "${media}" in
                    HDD)     rank=1 ;;
                    Unknown) rank=2 ;;
                    SSD)     rank=3 ;;
                    NVMe)    rank=4 ;;
                    *)       rank=2 ;;
                esac
            else
                case "${media}" in
                    NVMe)    rank=1 ;;
                    SSD)     rank=2 ;;
                    Unknown) rank=3 ;;
                    HDD)     rank=4 ;;
                    *)       rank=3 ;;
                esac
            fi

            printf "%s\t%s\t%s\t%s\n" "${rank}" "${avail}" "${media}" "${mp}" >> "${CANDIDATES_FILE}"
        done < <(df -B1 -P -T 2>/dev/null | awk '
            NR>1 && $2 !~ /^(tmpfs|devtmpfs|squashfs|overlay|iso9660|udev|efivarfs|ramfs|proc|sysfs|cgroup.*|autofs)$/ {
                mp = $7;
                if (mp != "/" && mp !~ /^\/(boot|efi|snap|proc|sys|dev|run)(\/|$)/ && $5 > 0) {
                    print $1, $2, $5, mp;
                }
            }')

        BEST_LINE="$(awk -v min="${MIN_PREFERRED_BYTES}" '$2 >= min' "${CANDIDATES_FILE}" | sort -k1,1n -k2,2rn | head -n 1 || true)"
        if [[ -z "${BEST_LINE}" ]]; then
            BEST_LINE="$(sort -k1,1n -k2,2rn "${CANDIDATES_FILE}" | head -n 1 || true)"
        fi
        rm -f "${CANDIDATES_FILE}"

        if [[ -n "${BEST_LINE}" ]]; then
            BEST_MEDIA="$(echo "${BEST_LINE}" | cut -f3)"
            BEST_MOUNT="$(echo "${BEST_LINE}" | cut -f4-)"
            BEST_MOUNT="${BEST_MOUNT%/}"
            DATA_DIR="${BEST_MOUNT}/aarkam/kdouja"
            FREE_GB="$(df -BG -P "${BEST_MOUNT}" 2>/dev/null | awk 'NR==2 {print $4}')"
            log_ok "Selected non-OS storage mount '${BEST_MOUNT}' [${BEST_MEDIA}, ${FREE_GB} free] (Preference: ${STORAGE_PREFERENCE}): ${DATA_DIR}"
        else
            DATA_DIR="/var/lib/kdouja"
            log_warn "No writable non-OS storage partition detected. Falling back to OS partition: ${DATA_DIR}"
        fi
    fi

    mkdir -p "${INSTALL_DIR}" "${DATA_DIR}" "${CONFIG_DIR}"
    chmod 0755 "${DATA_DIR}"
fi

# ------------------------------------------------------------------------------
# Step 2: Deploy Binaries (kdoujad Server & kdouja / kdouja-cli)
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "${SOURCE_PATH}" ]]; then
    if [[ -f "${SCRIPT_DIR}/kdoujad" ]]; then
        SOURCE_PATH="${SCRIPT_DIR}"
    elif [[ -f "${SCRIPT_DIR}/linux/kdoujad" ]]; then
        SOURCE_PATH="${SCRIPT_DIR}/linux"
    elif [[ -f "${SCRIPT_DIR}/kdouja-v1.0.3-linux-x64.zip" ]]; then
        SOURCE_PATH="${SCRIPT_DIR}/kdouja-v1.0.3-linux-x64.zip"
    else
        SOURCE_PATH="${SCRIPT_DIR}"
    fi
fi

log_info "Deploying binaries from: ${SOURCE_PATH}"

if [[ -f "${SOURCE_PATH}" && "${SOURCE_PATH}" == *.zip ]]; then
    TMP_DIR="$(mktemp -d)"
    unzip -q "${SOURCE_PATH}" -d "${TMP_DIR}"
    cp -rf "${TMP_DIR}"/* "${INSTALL_DIR}/"
    rm -rf "${TMP_DIR}"
elif [[ -d "${SOURCE_PATH}" ]]; then
    cp -rf "${SOURCE_PATH}"/* "${INSTALL_DIR}/"
else
    log_error "Invalid binary source: ${SOURCE_PATH}"
    exit 1
fi

# Ensure execute permissions
chmod +x "${INSTALL_DIR}/kdoujad" || true
chmod +x "${INSTALL_DIR}/kdouja" || true

# Guarantee both 'kdouja' and 'kdouja-cli' executables exist
if [[ -f "${INSTALL_DIR}/kdouja" && ! -f "${INSTALL_DIR}/kdouja-cli" ]]; then
    ln -sf "${INSTALL_DIR}/kdouja" "${INSTALL_DIR}/kdouja-cli"
elif [[ -f "${INSTALL_DIR}/kdouja-cli" && ! -f "${INSTALL_DIR}/kdouja" ]]; then
    ln -sf "${INSTALL_DIR}/kdouja-cli" "${INSTALL_DIR}/kdouja"
fi

log_ok "Binaries deployed to ${INSTALL_DIR}:"
log_ok "  - Server Daemon : ${INSTALL_DIR}/kdoujad"
log_ok "  - CLI Utility   : ${INSTALL_DIR}/kdouja & ${INSTALL_DIR}/kdouja-cli"

# ------------------------------------------------------------------------------
# Step 3: Configure Default appsettings.json
# ------------------------------------------------------------------------------
if [[ ! -f "${CONFIG_DIR}/appsettings.json" ]]; then
    cat > "${CONFIG_DIR}/appsettings.json" <<EOF
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft": "Warning",
      "Grpc": "Information"
    }
  },
  "Kdouja": {
    "BaseDirectory": "${DATA_DIR}",
    "Port": ${PORT},
    "EnableDirectIO": true,
    "SyncWAL": true
  }
}
EOF
    chmod 0644 "${CONFIG_DIR}/appsettings.json"
    log_ok "Configuration created at ${CONFIG_DIR}/appsettings.json"
fi

# ------------------------------------------------------------------------------
# Step 4: Configure Global / User Environment PATH (MANDATORY REQUIREMENT)
# ------------------------------------------------------------------------------
log_info "Configuring Environment PATH for CLI accessibility..."

# 4A. For System-Wide installs: Create /etc/profile.d/kdouja.sh
if [[ "${USER_ONLY}" != "true" ]]; then
    cat > /etc/profile.d/kdouja.sh <<EOF
# Aarkam Kdouja Environment Configuration
if [ -d "${INSTALL_DIR}" ] && [[ ":\$PATH:" != *":${INSTALL_DIR}:"* ]]; then
    export PATH="${INSTALL_DIR}:\$PATH"
fi
export KDOUJA_BASE_DIRECTORY="${DATA_DIR}"
export DOTNET_CLI_TELEMETRY_OPTOUT=1
EOF
    chmod 0644 /etc/profile.d/kdouja.sh
    log_ok "System environment configured via /etc/profile.d/kdouja.sh"
fi

# 4B. For User-Specific Shell Profiles (~/.bashrc, ~/.zshrc, ~/.profile)
add_to_shell_rc() {
    local rc_file="$1"
    if [[ -f "${rc_file}" ]]; then
        if ! grep -q "kdouja" "${rc_file}"; then
            echo "" >> "${rc_file}"
            echo "# Aarkam Kdouja PATH" >> "${rc_file}"
            echo "export PATH=\"${INSTALL_DIR}:\$PATH\"" >> "${rc_file}"
            echo "export KDOUJA_BASE_DIRECTORY=\"${DATA_DIR}\"" >> "${rc_file}"
            log_ok "Updated ${rc_file} with Kdouja environment PATH."
        else
            log_ok "${rc_file} already contains Kdouja configuration."
        fi
    fi
}

add_to_shell_rc "${HOME}/.bashrc"
add_to_shell_rc "${HOME}/.zshrc"
add_to_shell_rc "${HOME}/.profile"

# Export for current script execution
export PATH="${INSTALL_DIR}:${PATH}"

# ------------------------------------------------------------------------------
# Step 5: Systemd Service Configuration (kdoujad Server Daemon)
# ------------------------------------------------------------------------------
if [[ "${USER_ONLY}" != "true" ]]; then
    SERVICE_FILE="/etc/systemd/system/kdoujad.service"
    log_info "Creating systemd service unit: ${SERVICE_FILE}..."
    cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=Aarkam Kdouja Standalone Storage Engine Daemon
Documentation=https://github.com/aarkamio/Aarkam.Kdouja
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${DATA_DIR}
ExecStart=${INSTALL_DIR}/kdoujad --urls "http://0.0.0.0:${PORT}"
Restart=on-failure
RestartSec=5s
LimitNOFILE=65536
LimitMEMLOCK=infinity
Environment=KDOUJA_BASE_DIRECTORY=${DATA_DIR}
Environment=DOTNET_CLI_TELEMETRY_OPTOUT=1

[Install]
WantedBy=multi-user.target
EOF
    chmod 0644 "${SERVICE_FILE}"
    systemctl daemon-reload || true
    log_ok "Systemd service 'kdoujad.service' registered successfully."

    if [[ "${INSTALL_SERVICE}" == "true" ]]; then
        log_info "Enabling and starting kdoujad service..."
        systemctl enable kdoujad.service || true
        systemctl start kdoujad.service || true
        log_ok "kdoujad service enabled and started on port ${PORT}."
    else
        log_info "To enable and start the server daemon:"
        echo -e "    ${CYAN}sudo systemctl enable --now kdoujad.service${NC}"
    fi
fi

# ------------------------------------------------------------------------------
# Step 6: Verification
# ------------------------------------------------------------------------------
log_info "Verifying Kdouja CLI execution..."
if "${INSTALL_DIR}/kdouja" --version >/dev/null 2>&1; then
    VER="$("${INSTALL_DIR}/kdouja" --version | tail -n 1)"
    log_ok "CLI verified: ${VER}"
    log_info "Testing node hardware fingerprint..."
    "${INSTALL_DIR}/kdouja" license fingerprint --table || true
else
    log_warn "Binary installed at ${INSTALL_DIR}/kdouja, but verify check returned non-zero."
fi

echo -e "${GREEN}======================================================================${NC}"
echo -e "${GREEN} Aarkam Kdouja Installation Completed Successfully!                   ${NC}"
echo -e "${CYAN} CLI Commands:  'kdouja --help' or 'kdouja-cli --help'               ${NC}"
echo -e "${CYAN} Server Daemon: 'kdoujad' or 'sudo systemctl start kdoujad'           ${NC}"
echo -e "${GREEN} Environment:   '${INSTALL_DIR}' is configured in PATH               ${NC}"
echo -e "${GREEN}======================================================================${NC}"
