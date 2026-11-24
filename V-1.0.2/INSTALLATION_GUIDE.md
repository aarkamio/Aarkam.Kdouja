# Aarkam Kdouja Installation & Deployment Guide (Version kdouja-v1.0.2)

This guide provides instructions for deploying **Aarkam Kdouja** as an autonomous daemon (`kdoujad`), using the standalone administrative CLI (`kdouja`), or running via containerized environments across Linux, Windows, and Docker.

---

## 1. Quick Docker Deployment (Recommended)

### Run Storage Daemon Container
```bash
# Create local data directory
mkdir -p /var/lib/kdouja

# Run container with persistent storage
docker run -d \
  --name kdouja-server \
  --restart unless-stopped \
  -p 57771:57771 \
  -v /var/lib/kdouja:/var/lib/kdouja \
  -e KDOUJA_BASE_DIRECTORY="/var/lib/kdouja" \
  -e KDOUJA_MEMTABLE_FLUSH_MB="32" \
  -e KDOUJA_ENABLE_DIRECT_IO="false" \
  aarkam/aarkam.kdouja:v1.0.2
```

### Health Check
```bash
curl http://localhost:57771/healthz
```

### Run CLI / Interactive Shell in Container
```bash
# Query database metrics
docker run --rm -v /var/lib/kdouja:/var/lib/kdouja aarkam/aarkam.kdouja info --json

# Interactive administrative REPL shell
docker run -it --rm -v /var/lib/kdouja:/var/lib/kdouja aarkam/aarkam.kdouja repl
```

---

## 2. Linux Host Installation (`linux-x64`)

### Step 1: Download & Extract
```bash
unzip kdouja-v1.0.2-linux-x64.zip -d /opt/kdouja
cd /opt/kdouja
chmod +x kdoujad kdouja install-kdouja.sh entrypoint.sh
```

### Step 2: Run Installer
```bash
sudo ./install-kdouja.sh
```
This automated installation script:
- Symlinks `/usr/local/bin/kdoujad -> /opt/kdouja/kdoujad`
- Symlinks `/usr/local/bin/kdouja -> /opt/kdouja/kdouja`
- Symlinks `/usr/local/bin/kdouja-cli -> /opt/kdouja/kdouja` (backwards compatibility alias)
- Initializes `/var/lib/kdouja` (mode 0755) and `/etc/kdouja`
- Stages default `appsettings.json` configuration

### Step 3: Verify Installation
```bash
# Inspect version and help
kdouja --version
kdouja --help

# Query database info (automatically resolves KDOUJA_BASE_DIRECTORY or /var/lib/kdouja)
kdouja info --json

# Direct write and read operations
kdouja put "sensor:rack1" "optimal"
kdouja get "sensor:rack1"
```

---

## 3. Windows Installation (`win-x64`)

### Step 1: Extract Zip
Extract `kdouja-v1.0.2-win-x64.zip` into `C:\Program Files\Aarkam\Kdouja` (or temporary extraction folder).

### Step 2: Run Automated PowerShell Installer
Open PowerShell as Administrator:
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\install-kdouja.ps1
```
This script:
- Installs binaries and dependencies into `C:\Program Files\Aarkam\Kdouja`
- Creates database directory in `C:\ProgramData\Aarkam\Kdouja`
- Registers `C:\Program Files\Aarkam\Kdouja` into the System `PATH`
- Sets `KDOUJA_BASE_DIRECTORY` system environment variable
- Generates `kdouja-cli.cmd` wrapper for legacy tool scripts

### Step 3: Verify & Launch
Open a new PowerShell / Command Prompt terminal:
```powershell
# Launch interactive administrative shell
kdouja

# Or run commands directly
kdouja --help
kdoujad.exe
```

---

## 4. Sovereign Licensing, 30-Day Free Trial & Activation (`.arkbundle` / `.arklic`)

**Aarkam Kdouja** operates completely offline (zero telemetry / zero phone-home) under an **Aarkam Sovereign Root CA** cryptographic license model:

| Mode / Tier | Duration | Behavior | Activation Method |
| :--- | :--- | :--- | :--- |
| **Community Evaluation** | **Free for first 30 Days** | Full read/write access (up to 10 TB) | Automatic cryptographically sealed `.kdouja_init` trial on first startup |
| **Quarterly Subscription** | **90 Days (3 Months)** | Production workloads (up to 50 TB), hardware-locked | `.arkbundle` / `.arklic` via `kdouja license apply` |
| **Enterprise Sovereign** | **Annual / Multi-Year** | Unlimited capacity, multi-factor hardware lock | Sovereign Genesis `.arkbundle` via `kdouja license apply` |

> **What happens when the 30-day trial or license expires?**
> Kdouja automatically transitions into **Read-Only License-Locked mode**: all write operations (`put`, `delete`, `WriteBatch`) are rejected with `LICENSE_VIOLATION` / gRPC `PermissionDenied`, while read operations (`get`, `scan`) and `kdouja license apply` remain available so you never lose access to your data.

### Step 1: Extract Node Hardware Fingerprint
Extract the deterministic hardware fingerprint (`ARK-FP-...`) of the target host or container:

```bash
# Linux / Windows
kdouja license fingerprint

# Docker
docker exec kdouja-server kdouja license fingerprint
```

Submit this fingerprint to the **Aarkam Sovereign Portal** (or your Aarkam account representative) to issue your signed **`.arkbundle`** or **`.arklic`** certificate.

### Step 2: Inspect the Activation Bundle Offline (Optional)
Verify the Aarkam Sovereign Root CA RSA-4096 / SHA-512 PSS signature and hardware compatibility before applying:

```bash
kdouja license inspect --file /path/to/kdouja-license.arkbundle
```

### Step 3: Activate or Renew (Update) Your License
Apply the signed `.arkbundle` or `.arklic` file to your database directory. Use the **exact same command** both for initial activation and for **updating/renewing** an existing license before or after expiration:

```bash
# Linux (default data dir: /var/lib/kdouja)
kdouja license apply --file /path/to/kdouja-license.arkbundle --dir /var/lib/kdouja

# Windows PowerShell (default data dir: C:\ProgramData\Aarkam\Kdouja)
kdouja license apply --file C:\path\to\kdouja-license.arkbundle --dir "C:\ProgramData\Aarkam\Kdouja"

# Docker (mount the bundle read-only into the container)
docker run --rm \
  -v /var/lib/kdouja:/var/lib/kdouja \
  -v /path/to/kdouja-license.arkbundle:/tmp/license.arkbundle:ro \
  aarkam/aarkam.kdouja:v1.0.2 \
  license apply --file /tmp/license.arkbundle --dir /var/lib/kdouja
```

- Kdouja verifies the **Aarkam Sovereign Root CA** signature, `Product = Kdouja`, payment status, expiration, and node hardware fingerprint, then seals `kdouja.license` and `.kdouja_audit` inside the data directory.
- If `kdoujad` was in Read-Only License-Locked mode, applying a valid bundle unlocks write operations immediately without requiring data migration.

### Step 4: Verify License Status & Re-Audit
```bash
# Check active tier, days remaining, and cryptographic audit seal
kdouja license status --dir /var/lib/kdouja

# Force a hardware re-audit after an engine upgrade
kdouja license reaudit --dir /var/lib/kdouja --force
```

---

## 5. In-Process Library Embedding (.NET 8 & 10)

Add package to your project:
```xml
<PackageReference Include="Aarkam.Kdouja.Engine" Version="1.0.2" />
```

```csharp
using Aarkam.Kdouja.Abstractions.CommonOptions;
using Aarkam.Kdouja.Engine.Core;

var options = new EngineOptions
{
    BaseDirectory = "/var/lib/kdouja",
    MemTableFlushThresholdBytes = 32 * 1024 * 1024,
    EnableDirectIO = true,
    PageSizeBytes = 4096,
    EnableWalFsync = true
};

using var engine = new KeyValueEngine(options);
await engine.PutAsync("key1"u8.ToArray(), "val1"u8.ToArray());
var val = await engine.GetAsync("key1"u8.ToArray());
```
