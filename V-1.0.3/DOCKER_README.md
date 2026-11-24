<div align="center">

# Aarkam Kdouja — Sovereign LSM & Direct-I/O Storage Engine
### Autonomous Log-Structured Merge Storage Engine, Direct NVMe PageStore & High-Throughput Substrate

[![Version](https://img.shields.io/badge/version-v1.0.2--GA-blue.svg?style=for-the-badge&logo=semver)](https://github.com/aarkamio/Aarkam.Kdouja)
[![Docker Image](https://img.shields.io/badge/docker-aarkam%2Faarkam.kdouja-2496ED.svg?style=for-the-badge&logo=docker)](https://hub.docker.com/r/aarkam/aarkam.kdouja)
[![Target OS](https://img.shields.io/badge/platform-Linux%20x64%20%7C%20Windows%20x64-333333.svg?style=for-the-badge&logo=linux)](https://github.com/aarkamio/Aarkam.Kdouja)
[![Architecture](https://img.shields.io/badge/arch-x86__64%20(AVX2)-orange.svg?style=for-the-badge)](https://github.com/aarkamio/Aarkam.Kdouja)
[![Compliance](https://img.shields.io/badge/compliance-NCA%20ECC--2%3A2024%20%7C%20FIPS%20140--3-darkgreen.svg?style=for-the-badge)](https://github.com/aarkamio/Aarkam.Kdouja)
[![Air-Gapped](https://img.shields.io/badge/network-100%25%20Air--Gapped%20Zero--Egress-critical.svg?style=for-the-badge)](https://github.com/aarkamio/Aarkam.Kdouja)

</div>

---

## 1. What is Kdouja?

**Aarkam Kdouja** is the high-performance autonomous storage engine of the **Aarkam Sovereign Data Fabric**. Operating directly on bare-metal NVMe drives and containerized enterprise substrates, Kdouja delivers sub-millisecond point lookups, zero-allocation LSM memory structures, hardware-level Direct I/O block allocation, and native AES-256 Write-Ahead Log (WAL) durability across sovereign cloud environments.

Kdouja serves as the foundational storage substrate for:
1. **Aarkam Rokka**: Powers local object catalog indexing, bucket metadata tables, and high-frequency SSTable deduplication.
2. **Aarkam Abodi**: Powers unbuffered 66,048-byte physical block allocations, Cauchy shard placement, and direct NVMe queue saturation.
3. **Autonomous Edge Nodes**: Operates as a zero-dependency, self-contained embedded storage engine or network daemon (`kdoujad`) with dedicated inspection tooling (`kdouja`).

Engineered strictly for **zero-egress, air-gapped sovereign datacenters**, Kdouja operates with complete autonomy—requiring zero external database dependencies (no Redis, no ZooKeeper), zero third-party internet callbacks, and zero native C++ redistributable packages.

---

## 2. Quick Start

### Pull the Image

```bash
docker pull aarkam/aarkam.kdouja:latest
# or explicit version
docker pull aarkam/aarkam.kdouja:v1.0.2
```

---

## 3. Usage Modes

### Mode A: Autonomous Storage Daemon (`kdoujad`)

Run Kdouja as an autonomous background daemon exposing high-throughput gRPC services (`KeyValueService` and `StorageService`) on port **57771**:

```bash
docker run -d \
  --name kdouja-server \
  -p 57771:57771 \
  -v kdouja_data:/var/lib/kdouja \
  -e KDOUJA_BASE_DIRECTORY="/var/lib/kdouja" \
  -e KDOUJA_MEMTABLE_FLUSH_MB="32" \
  -e KDOUJA_ENABLE_DIRECT_IO="false" \
  aarkam/aarkam.kdouja:v1.0.2
```

Check server health:
```bash
curl http://localhost:57771/healthz
```

---

### Mode B: Enterprise CLI & Inspector (`kdouja`)

Use the bundled `kdouja` tool to query keys, inspect SSTables, view metrics, trigger compactions, or run the interactive shell. Note that `--dir` automatically defaults to `/var/lib/kdouja` (`KDOUJA_BASE_DIRECTORY`):

```bash
# Display engine diagnostics in structured JSON
docker run --rm \
  -v kdouja_data:/var/lib/kdouja \
  aarkam/aarkam.kdouja info --json

# Store a key-value record (direct shorthand or 'kv put')
docker run --rm \
  -v kdouja_data:/var/lib/kdouja \
  aarkam/aarkam.kdouja put "config:mode" "sovereign"

# Read a record
docker run --rm \
  -v kdouja_data:/var/lib/kdouja \
  aarkam/aarkam.kdouja get "config:mode"

# Trigger manual SSTable compaction pass
docker run --rm \
  -v kdouja_data:/var/lib/kdouja \
  aarkam/aarkam.kdouja compact --json

# Launch interactive administrative REPL shell
docker run -it --rm \
  -v kdouja_data:/var/lib/kdouja \
  aarkam/aarkam.kdouja repl
```

---

## 4. Why Kdouja Wins Against Competitors

| Metric / Capability | **Aarkam Kdouja** | **RocksDB** (Meta) | **Pebble** (CockroachDB) | **BadgerDB** (Dgraph) |
| :--- | :--- | :--- | :--- | :--- |
| **Architecture** | **Hybrid LSM + Direct-I/O PageStore** | Pure LSM-Tree | Pure LSM-Tree | LSM + Value Log (WiscKey) |
| **Kernel Cache Bypassing** | **Yes** (`O_DIRECT` / Unbuffered) | Complex manual setup | No (OS Page Cache) | No (OS Page Cache) |
| **Write Amplification (WAF)** | **Low** (1.2–3.5x on payloads) | High (10–30x) | High (10–25x) | **Low** (2–4x) |
| **Built-in Daemon** | **Native gRPC** (`kdoujad`) | None (Library only) | None (Library only) | None (Library only) |
| **Runtime Dependencies** | **Zero** (.NET 8/10 Managed) | C++17 runtime libs | Go runtime | Go runtime |
| **Hardware Encryption** | **Native AES-256 WAL** | Custom plugin required | None | Native AES-256 |

---

## 5. Environment Variables

| Variable | Default | Description |
| :--- | :--- | :--- |
| `KDOUJA_BASE_DIRECTORY` | `/var/lib/kdouja` | Path to persistent database directory |
| `KDOUJA_MEMTABLE_FLUSH_MB` | `32` | Size threshold in MB to flush MemTable to L0 SSTable |
| `KDOUJA_MAX_L0_FILES` | `4` | Number of L0 SSTables before triggering compaction |
| `KDOUJA_ENABLE_DIRECT_IO` | `false` | Enable unbuffered Direct I/O (`O_DIRECT`) on Linux |
| `KDOUJA_PAGE_SIZE` | `4096` | Direct I/O page allocation size in bytes (4KB) |
| `KDOUJA_ENABLE_WAL_FSYNC` | `true` | Force hardware fsync barrier on every commit |
| `KDOUJA_WAL_KEY` | *(Auto-generated)* | 64-character hex AES-256 key for WAL at-rest encryption |
| `DOTNET_CLI_TELEMETRY_OPTOUT`| `1` | Disables telemetry for hardened air-gapped environments |

---

## 6. Persistent Volumes

| Mount Path | Description | Recommended Usage |
| :--- | :--- | :--- |
| `/var/lib/kdouja` | Database data directory (SSTables, WAL, PageStore) | Mount high-speed NVMe block volume |
| `/etc/kdouja` | Static configuration overrides | Mount custom `appsettings.json` |

---

## 7. Docker Compose Example

```yaml
version: '3.8'

services:
  kdouja:
    image: aarkam/aarkam.kdouja:v1.0.2
    container_name: aarkam-kdouja
    restart: unless-stopped
    ports:
      - "57771:57771"
    environment:
      - KDOUJA_BASE_DIRECTORY=/var/lib/kdouja
      - KDOUJA_MEMTABLE_FLUSH_MB=64
      - KDOUJA_ENABLE_WAL_FSYNC=true
      - KDOUJA_ENABLE_DIRECT_IO=false
    volumes:
      - ./kdouja_data:/var/lib/kdouja
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:57771/healthz"]
      interval: 10s
      timeout: 3s
      retries: 3
```

---

## 8. Security & Sovereign Compliance

- **Saudi NCA ECC-2:2024 & FIPS 140-3**: Cryptographic isolation, authenticated memory bounds, and native AES-256 WAL encryption at rest.
- **100% Air-Gapped**: Runs entirely offline in disconnected data centers.
- **Zero Kernel Thrashing**: Sector-aligned Direct I/O eliminates dirty-page memory leaks on long-running nodes.
- **Documentation**: [https://github.com/aarkamio/Aarkam.Kdouja](https://github.com/aarkamio/Aarkam.Kdouja)
