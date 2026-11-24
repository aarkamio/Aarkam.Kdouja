# Aarkam Kdouja Installation & Deployment Guide (Version V-1.0.3)

This guide covers the deployment of **Aarkam Kdouja** (Server Daemon and CLI) on Linux and Windows platforms with automatic environment PATH configuration.

---

## 🚀 Quick Automated Installation

### 1. Windows Installation (PowerShell)

Run PowerShell as Administrator (or standard user for user-space install):

```powershell
# Extract release archive:
Expand-Archive -Path .\kdouja-v1.0.3-win-x64.zip -DestinationPath .\kdouja-install

# Run the automated installer:
cd .\kdouja-install
.\install-kdouja.ps1
```

#### What the Windows Installer Does:
1. **Installs Binaries**: Deploys both Server Daemon (`kdoujad.exe`) and CLI (`kdouja.exe` / `kdouja-cli.exe`) to `C:\Program Files\Aarkam\Kdouja` (or `%LOCALAPPDATA%\Aarkam\Kdouja` if non-admin).
2. **Configures PATH Environment**: Permanently prepends the installation directory to Machine/User `Path` environment variable.
3. **Instant Shell Recognition**: Broadcasts `WM_SETTINGCHANGE` so all active and future Windows terminal windows (PowerShell, Command Prompt, Windows Terminal) recognize `kdouja` and `kdouja-cli` immediately without restarting.
4. **Initializes Data & Config**: Sets up `C:\ProgramData\Aarkam\Kdouja\data` and default `appsettings.json`.
5. **Generates Daemon Launcher**: Creates `start-kdoujad.cmd` for quick interactive background execution.
6. **Optional Windows Service**: Pass `-InstallServerService` to automatically register `kdoujad` as a background Windows Service (`KdoujaServer`).

---

### 2. Linux Installation (Bash)

Supported Distributions: Ubuntu 22.04/24.04 LTS, Debian 12+, RHEL/Rocky/AlmaLinux 9+ (x86_64).

```bash
# Extract release archive:
unzip kdouja-v1.0.3-linux-x64.zip -d kdouja-install
cd kdouja-install

# Run the automated installer with root/sudo:
sudo ./install-kdouja.sh --service
```

#### What the Linux Installer Does:
1. **Installs Binaries**: Copies `kdoujad` and `kdouja` into `/usr/local/bin` with `0755` permissions.
2. **Configures PATH Environment**:
   - Creates `/etc/profile.d/kdouja.sh` ensuring `/usr/local/bin` is in system-wide `$PATH`.
   - Adds exports to user profiles (`~/.bashrc`, `~/.zshrc`, `~/.profile`).
   - Creates symlink `kdouja-cli -> kdouja` so both command forms work out of the box.
3. **Sets Up Data Directory**: Creates `/var/lib/kdouja` with proper POSIX isolation.
4. **Provisions systemd Service**: Creates `/etc/systemd/system/kdoujad.service` unit with high file descriptor limits (`LimitNOFILE=65536`) and locked memory (`LimitMEMLOCK=infinity`).
5. **Starts Daemon**: Enables and starts the background service when `--service` is provided.

---

## 🛠️ Verification & CLI Usage

Once installed, verify that the CLI is accessible from any terminal window:

```bash
# Verify CLI version:
kdouja --version
# or using the full name:
kdouja-cli --version

# Display system information & hardware capabilities:
kdouja info --json
```

---

## 🔑 Licensing & Node Hardware Fingerprinting

Kdouja operates air-gapped on-node without internet or phone-home telemetry.

### 1. Extract Node Fingerprint
Generate your host's deterministic hardware fingerprint needed to issue a quarterly activation bundle:

```bash
kdouja license fingerprint --table
# or JSON:
kdouja license fingerprint --json
```

*Sample Output:*
```text
╔══════════════════════════════════════════════════════════════════════════════╗
║            AARKAM KDOUJA NODE CRYPTOGRAPHIC HARDWARE FINGERPRINT             ║
╠══════════════════════════════════════════════════════════════════════════════╣
║ Node Fingerprint :  ARK-FP-AD8FF9EE-77AEB122-F222165B                        ║
║ Host Name        :  STORAGE-NODE-01                                          ║
║ Architecture     :  X64                                                      ║
║ CPU Cores        :  16                                                       ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

### 2. Apply Activation Bundle
Apply the issued `.arkbundle` or `.arklic` quarterly license file:

```bash
kdouja license apply --file /path/to/kdouja.arkbundle
```
* **Single-Registration Sealing**: The license verifies against the node fingerprint and seals into `.kdouja_audit`.
* **Zero Overhead**: Routine operations bypass hardware audits for microsecond storage throughput.
* **Automatic Upgrade Re-Audit**: When upgrading to a new Kdouja binary, the engine automatically re-audits the node hardware and reseals.

### 3. Check License & Evaluation Status
```bash
kdouja license status --table
```

---

## 🌐 Running the Autonomous Server Daemon (`kdoujad`)

### On Linux (systemd)
```bash
# Manage service:
sudo systemctl status kdoujad
sudo systemctl restart kdoujad
sudo journalctl -u kdoujad -f
```

### On Windows
* **Interactive Launcher**: Run `start-kdoujad.cmd` located in `C:\Program Files\Aarkam\Kdouja`.
* **Windows Service**: Run `Start-Service KdoujaServer` or `net start KdoujaServer`.

### Standalone Command Line
```bash
kdoujad --urls "http://0.0.0.0:57771"
```

---

## 🐳 Docker Container Deployment

```bash
# Pull official release image:
docker pull aarkam/aarkam.kdouja:v1.0.3

# Run background daemon container:
docker run -d \
  --name kdouja-server \
  -p 57771:57771 \
  -v kdouja_data:/var/lib/kdouja \
  -e KDOUJA_BASE_DIRECTORY="/var/lib/kdouja" \
  -e KDOUJA_ENABLE_DIRECT_IO="false" \
  aarkam/aarkam.kdouja:v1.0.3

# Execute CLI commands in container:
docker run --rm -v kdouja_data:/var/lib/kdouja aarkam/aarkam.kdouja:v1.0.3 info --table
```
