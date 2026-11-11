# Aarkam Kdouja Installation & Deployment Guide (Version kdouja-v1.0.1)

This guide provides instructions for deploying **Aarkam Kdouja** as an autonomous daemon, using the administrative CLI, or running via Docker containers.

---

## 1. Quick Docker Deployment (Recommended)

### Run Storage Daemon Container
```bash
# Create local data directory
mkdir -p /var/lib/kdouja

# Run container
docker run -d \
  --name kdouja-server \
  --restart unless-stopped \
  -p 57771:57771 \
  -v /var/lib/kdouja:/var/lib/kdouja \
  -e KDOUJA_BASE_DIRECTORY="/var/lib/kdouja" \
  -e KDOUJA_MEMTABLE_FLUSH_MB="32" \
  -e KDOUJA_ENABLE_DIRECT_IO="false" \
  aarkam/aarkam.kdouja:v1.0.1
```

### Health Check
```bash
curl http://localhost:57771/healthz
```

---

## 2. Linux Host Installation (`linux-x64`)

### Step 1: Download & Extract
```bash
unzip kdouja-v1.0.1-linux-x64.zip -d /opt/kdouja
cd /opt/kdouja
chmod +x kdoujad kdouja-cli install-kdouja.sh
```

### Step 2: Run Installer
```bash
sudo ./install-kdouja.sh
```
This symlinks binaries to `/usr/local/bin` and optionally sets up a systemd service `kdoujad.service`.

### Step 3: Verify Installation
```bash
kdouja-cli --version
kdouja-cli info --dir /var/lib/kdouja --json
```

---

## 3. Windows Installation (`win-x64`)

### Step 1: Extract Zip
Extract `kdouja-v1.0.1-win-x64.zip` into `C:\Program Files\Aarkam\Kdouja`.

### Step 2: Run Setup
Open PowerShell as Administrator:
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\install-kdouja.ps1
```

### Step 3: Run Engine Daemon
```powershell
kdoujad.exe
```

---

## 4. In-Process Library Embedding (.NET 8 & 10)

Add package to your `.csproj`:
```xml
<PackageReference Include="Aarkam.Kdouja.Engine" Version="1.0.1" />
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
