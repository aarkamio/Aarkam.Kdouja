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

## 4. In-Process Library Embedding (.NET 8 & 10)

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
