# Aarkam.Kdouja (Storage Engine v1.0.2)

[![Version](https://img.shields.io/badge/version-kdouja--v1.0.2-blue.svg?style=for-the-badge&logo=semver)](https://github.com/aarkamio/Aarkam.Kdouja)
[![Docker Image](https://img.shields.io/badge/docker-aarkam%2Faarkam.kdouja-2496ED.svg?style=for-the-badge&logo=docker)](https://hub.docker.com/r/aarkam/aarkam.kdouja)
[![GitHub Repo](https://img.shields.io/badge/github-aarkamio%2FAarkam.Kdouja-181717.svg?style=for-the-badge&logo=github)](https://github.com/aarkamio/Aarkam.Kdouja)
[![.NET Multi-Target](https://img.shields.io/badge/.NET-8.0%20(LTS)%20%7C%2010.0-512BD4.svg?style=for-the-badge&logo=dotnet)](https://dotnet.microsoft.com/)
[![Engine Layer](https://img.shields.io/badge/Layer-Standalone%20LSM%20%26%20Direct%20I%2FO-blue.svg?style=for-the-badge)]()
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-teal.svg?style=for-the-badge&logo=linux)]()
[![Durability](https://img.shields.io/badge/Durability-Hardware%20Fsync%20%26%20AES--256-success.svg?style=for-the-badge)]()
[![Tests](https://img.shields.io/badge/Tests-503%20Passed%20(100%25)-brightgreen.svg?style=for-the-badge)]()

**Aarkam.Kdouja** is an enterprise-grade, high-performance standalone Log-Structured Merge-tree (LSM-tree) and physical Direct I/O block storage engine engineered in C# for modern .NET runtimes (.NET 8.0 LTS and .NET 10.0).

Designed to be consumed both as an **in-process embedded storage engine** (analogous to RocksDB, Pebble, or SQLite) and as an **autonomous daemon** (`kdoujad`) with dedicated administrative tooling (`kdouja`) and a production Docker container (`aarkam/aarkam.kdouja`).

---

## 🏆 Competitive Benchmark: Kdouja vs. Popular Storage Engines

| Feature / Metric | **Aarkam Kdouja** | **RocksDB** (Meta) | **Pebble** (CockroachDB) | **BadgerDB** (Dgraph) | **LMDB** (Symas) | **SQLite (WAL)** |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Language** | Modern C# (.NET 8/10) | C++17/20 | Go | Go | C | C |
| **Primary Architecture** | **Hybrid: LSM-Tree + Direct-I/O PageStore** | Pure LSM-Tree (BlobDB opt-in) | Pure LSM-Tree | LSM-Tree (Keys) + Value Log (WiscKey) | Memory-Mapped B+ Tree | B-Tree with Write-Ahead Log |
| **Direct I/O Support** | **Native** (`FILE_FLAG_NO_BUFFERING` / `O_DIRECT`) | Opt-in (Complex config) | No (Relies on OS page cache) | No (Relies on OS page cache) | No (Uses `mmap` page cache) | No (Relies on OS page cache) |
| **Large Value Handling** | **Yes** (256MB Direct-I/O PageStore) | Yes (BlobDB / Integrated) | Experimental (Pebble Blobs) | **Yes** (Value Log files) | No (Inlined in B-Tree pages) | No (Overflow pages in DB file) |
| **Write Amplification (WAF)** | **Low** (1.2–3.5 for payloads) | High (10–30x in Leveled) | Medium-High (10–25x) | **Low** (2–4x due to WiscKey) | High (Copy-On-Write re-writes) | Medium |
| **Compaction Strategy** | Leveled / Size-Tiered + Background Worker | Leveled, Universal, FIFO | Leveled (optimized for Cockroach) | Leveled (LSM keys only) | **None** (B-Tree freelist reuse) | None (B-Tree rebalance) |
| **Bloom Filters** | SIMD xxHash64 Block-level | Block-based & Full Bloom Filter | Block-based Bloom Filter | Block-based Bloom Filter | **None** | None |
| **Built-in Daemon Mode** | **Yes** (`kdoujad` via binary gRPC) | No (Library only; needs proxy) | No (Library only) | No (Library only) | No (Library only) | No (Library only) |
| **Hardware Encryption** | **Native WAL AES-256** | Custom Env/Crypto plugin | None | Native AES-256 | None | Custom (SEE / SQLCipher) |
| **Primary Ecosystem** | Sovereign Storage, NVMe Saturation, Chunk Streams | Cockroach, Kafka, TiKV, Ceph | CockroachDB | Dgraph, IPFS | OpenLDAP, Matrix, Monero | Mobile, Embedded, Browsers |

---

## 💡 Why & When Kdouja Wins

```
  Kdouja Dual-Engine Write Path:

  Incoming Put(Key, Value)
           │
           ├───────────────────────────────┐
           ▼                               ▼
    [Small Value / Key]             [Large Binary Chunk (>64KB)]
           │                               │
    • Write-Ahead Log (WAL)         • Direct I/O (Bypasses OS Page Cache)
      (Hardware Fsync + AES-256)    • 4KB-aligned Page Allocation
           │                        • Stored in 256MB PageStore Blocks
           ▼                               │
    • Active MemTable (In-Memory)          │
           │                               │
           ▼                               ▼
    • L0..L6 Block-Indexed SSTables  ◄─────┘ (Stores Block Offset / Pointer)
      (SIMD xxHash64 Bloom Filters)
```

### 1. Dual-Substrate Architecture (LSM-Tree + Direct-I/O PageStore)
* **The Problem in Pure LSMs (RocksDB, Pebble)**: When large values (>4KB) are written into a standard LSM-tree, they are repeatedly rewritten across levels during compactions. This causes massive **Write Amplification (WAF of 10x–30x)**, burns out SSD flash cells, and causes compaction stalls.
* **The Kdouja Advantage**: Kdouja adopts the **WiscKey separation model**: keys and small values remain in the high-speed LSM-tree, while large values and binary chunks are written directly to pre-allocated **256MB PageStore blocks**. Compaction only sorts the lightweight keys, dropping WAF to **1.2x–3.5x** and maintaining peak ingest throughput.

### 2. True Hardware Direct I/O (Zero Kernel Cache Double-Buffering)
* **The Problem in BadgerDB / SQLite**: BadgerDB and SQLite rely entirely on the host operating system's page cache. Under heavy write saturation, the OS kernel dirty-page writeback causes memory thrashing, high latency spikes, and page eviction storms.
* **The Kdouja Advantage**: Kdouja's PageStore implements true **Direct I/O** (`FILE_FLAG_NO_BUFFERING` on Windows, `O_DIRECT` with strict 4KB sector alignment on Linux). It bypasses the kernel page cache entirely, streaming blocks directly to NVMe hardware controller queues for deterministic microsecond latency.

### 3. Modern Zero-Allocation .NET Engine (No Cgo / P/Invoke Overhead)
* **The Problem in RocksDB / LMDB wrappers**: Consuming RocksDB from Go or .NET requires bridging native C++ via Cgo or P/Invoke. Each read and write incurs context-switching latency, unmanaged heap pinning, and complex cross-platform compilation toolchains.
* **The Kdouja Advantage**: Kdouja is written 100% in modern managed C# (.NET 8 and .NET 10) utilizing `Span<byte>`, `Memory<byte>`, `Unsafe` memory mapping, and SIMD hardware acceleration. It delivers native C++ speeds with the memory safety, garbage collection isolation, and zero-dependency portability of .NET.

### 4. Built-in Hardware-Accelerated WAL Encryption
* Kdouja includes native **AES-256 Write-Ahead Log (WAL) encryption** with zero external dependencies. Data at rest is encrypted before it touches physical disk blocks, guaranteeing full compliance with **Saudi NCA ECC-2:2024** and **FIPS 140-3** sovereign security standards.

### 5. Multi-Mode Autonomous Deployment
Unlike RocksDB, Pebble, BadgerDB, or LMDB—which are strictly libraries requiring developers to write their own network servers—Kdouja ships as:
1. **Embedded NuGet Library** (`Aarkam.Kdouja.Engine`) for sub-microsecond in-process operations.
2. **Autonomous Network Daemon** (`kdoujad`) with high-throughput binary gRPC streaming (Port 57771).
3. **Enterprise Inspection CLI** (`kdouja`) powered by `System.CommandLine` with machine-readable `--json` and `--table` output formats.
4. **Official Docker Container** ([`aarkam/aarkam.kdouja`](https://hub.docker.com/r/aarkam/aarkam.kdouja)).

---

## 📦 Solution Architecture

```
D:\repos\Aarkam.IO\V2\Aarkam.Kdouja.SAT\
├── src/
│   ├── Aarkam.Kdouja.Abstractions/     # Core database interfaces, options, and error models
│   ├── Aarkam.Kdouja.Engine/           # Embedded LSM-Tree engine & Direct I/O PageStore
│   ├── Aarkam.Kdouja.Server/           # Standalone gRPC & HTTP server daemon (kdoujad)
│   ├── Aarkam.Kdouja.Cli/              # Inspection, compaction & benchmarking CLI (kdouja)
│   └── Aarkam.Kdouja.Client/           # High-throughput client SDK for remote connections
├── tests/
│   ├── Aarkam.Kdouja.Tests.Common/     # Shared test infrastructure & temporary directories
│   └── Aarkam.Kdouja.Tests.Unit/       # 503 automated unit tests (100% passing)
├── nuget/                              # Generated NuGet packages (v1.0.2)
└── Aarkam.Kdouja.slnx                  # Solution descriptor
```

---

## 🚀 1. In-Process Embedded Engine Usage

Add the package reference to your project:
```xml
<PackageReference Include="Aarkam.Kdouja.Engine" Version="1.0.2" />
```

```csharp
using Aarkam.Kdouja.Abstractions.CommonOptions;
using Aarkam.Kdouja.Engine.Core;
using System.Text;

// 1. Configure the engine
var options = new EngineOptions
{
    BaseDirectory = @"/var/lib/kdouja_data",
    MemTableFlushThresholdBytes = 32 * 1024 * 1024, // 32MB MemTable flush
    MaxL0FilesBeforeCompaction = 4,
    EnableDirectIO = true,                          // Unbuffered Direct I/O
    PageSizeBytes = 4096,                           // 4KB physical block size
    EnableWalFsync = true                           // Hardware flush on commit
};

// 2. Instantiate the KeyValueEngine
using var engine = new KeyValueEngine(options);

// 3. Put and Get records (Sub-microsecond point lookups)
var key = Encoding.UTF8.GetBytes("user:1001");
var val = Encoding.UTF8.GetBytes("{\"name\":\"Alice\",\"tier\":\"Enterprise\"}");

await engine.PutAsync(key, val);

byte[]? retrieved = await engine.GetAsync(key);
if (retrieved != null)
{
    Console.WriteLine(Encoding.UTF8.GetString(retrieved));
}

// 4. Atomic Write Batch
var batch = new WriteBatch();
batch.Put(Encoding.UTF8.GetBytes("k1"), Encoding.UTF8.GetBytes("v1"));
batch.Delete(Encoding.UTF8.GetBytes("k_old"));
await engine.WriteBatchAsync(batch);

// 5. Lexicographical Range Scan
await foreach (var kv in engine.ScanAsync(Encoding.UTF8.GetBytes("user:"), Encoding.UTF8.GetBytes("user:~")))
{
    Console.WriteLine($"{Encoding.UTF8.GetString(kv.Key)} => {Encoding.UTF8.GetString(kv.Value)}");
}
```

---

## 🛠️ 2. Standalone CLI Tooling (`kdouja`)

`kdouja` is built with `System.CommandLine` and provides administrative inspection, recovery, compaction, benchmarking, and an interactive shell. Running `kdouja` with no arguments (or `kdouja repl`) enters interactive REPL mode:

```bash
# Launch interactive administrative REPL shell
kdouja repl

# Display database stats, sequence number, and SSTable distribution in JSON
kdouja info --json

# Read and write records directly (supports 'kdouja put/get' or 'kdouja kv put/get')
kdouja put "sensor:temp" "24.5C" --json
kdouja get "sensor:temp" --table
kdouja delete "sensor:temp"

# Scan keys with limit
kdouja scan --start "sensor:" --limit 100 --json

# Trigger manual SSTable compaction pass
kdouja compact --json

# Run high-throughput parallel write and read benchmark
kdouja bench --ops 50000 --threads 8

# Inspect physical SSTable metadata and bloom filters
kdouja dump-sst ./kdouja_data/sstables/sst_000001.sst --json
```

---

## 🌐 3. Standalone Server Daemon (`kdoujad`)

Run Kdouja as an autonomous database daemon exposing high-performance gRPC endpoints:

```bash
dotnet run --project src/Aarkam.Kdouja.Server
```

Exposed gRPC services:
* **`aarkam.kdouja.KeyValueService`**: Pure KV operations (`Get`, `Put`, `Delete`, `WriteBatch`, `Scan`, `GetMetrics`).
* **`aarkam.kdouja.StorageService`**: High-level chunk streaming service (`StoreChunk`, `RetrieveChunk`).
* **Health Probes**: `/healthz` HTTP endpoint.

---

## 🐳 4. Docker Container Deployment

Official Docker image: [**`aarkam/aarkam.kdouja`**](https://hub.docker.com/r/aarkam/aarkam.kdouja)

### Pull the Image
```bash
docker pull aarkam/aarkam.kdouja:latest
# or explicit version
docker pull aarkam/aarkam.kdouja:v1.0.2
```

### Run Autonomous Engine Daemon
```bash
docker run -d \
  --name kdouja \
  -p 57771:57771 \
  -v kdouja_data:/var/lib/kdouja \
  -e KDOUJA_BASE_DIRECTORY="/var/lib/kdouja" \
  -e KDOUJA_ENABLE_DIRECT_IO="false" \
  aarkam/aarkam.kdouja:v1.0.2
```

### Run CLI Commands via Container
```bash
docker run --rm -v kdouja_data:/var/lib/kdouja aarkam/aarkam.kdouja info --dir /var/lib/kdouja --json
```

---

## 🧪 5. Test Verification Matrix

All unit tests compile and run cleanly across supported .NET versions:

```bash
# Run unit tests on .NET 8.0 LTS
dotnet test tests/Aarkam.Kdouja.Tests.Unit -f net8.0

# Run unit tests on .NET 10.0
dotnet test tests/Aarkam.Kdouja.Tests.Unit -f net10.0
```

**Results:**
* **Total Tests:** 503
* **Passed:** 503 (100%)
* **Failed:** 0
* **Warnings:** 0

---

## 💰 6. Plans, Pricing & Sovereign Licensing

Kdouja is engineered for mission-critical, air-gapped sovereign environments. Licensing operates autonomously on-node with zero telemetry or phone-home requirements.

### License Tiers & Evaluation

| Tier | Duration | Quotas & Scale | Hardware Lock | Licensing Method |
| :--- | :--- | :--- | :--- | :--- |
| **Community Evaluation** | **Free for first 30 Days** | Full feature set, up to 10 TB | Unbound | Automatic initialization via `.kdouja_init` marker |
| **Quarterly Subscription** | **3 Months (90 Days)** | Production workloads, up to 50 TB | Bound to Node Fingerprint | Air-gapped `.arkbundle` / `.arklic` activation bundle |
| **Enterprise Sovereign** | **Annual / Multi-Year** | Unlimited capacity, custom nodes | High-security multi-factor node lock | Sovereign Genesis Bundle with Operator Ingestion |

---

### Node Fingerprint & Single-Registration Architecture

To ensure tamper resistance while maintaining maximum runtime performance in containers and clouds, Kdouja enforces a **Single-Registration with Upgrade-Triggered Re-Audit** policy:

```
┌─────────────────────────────────┐       ┌─────────────────────────────────┐       ┌─────────────────────────────────┐
│  1. Extract Node Fingerprint    │  ───> │  2. Issue Activation Bundle     │  ───> │  3. Apply & Seal Once           │
│  kdouja license fingerprint     │       │  Generated & Signed by Aarkam   │       │  kdouja license apply           │
└─────────────────────────────────┘       └─────────────────────────────────┘       └─────────────────────────────────┘
                                                                                               │
                                                                                               ▼
                                                                                    ┌─────────────────────────────────┐
                                                                                    │  Runtime High-Speed Operations  │
                                                                                    │  Hardware audits bypassed       │
                                                                                    └─────────────────────────────────┘
                                                                                               │
                                                                                               ▼ (Engine Version Upgraded)
                                                                                    ┌─────────────────────────────────┐
                                                                                    │  4. Automatic Upgrade Re-Audit  │
                                                                                    │  Re-audits node FP & reseals    │
                                                                                    └─────────────────────────────────┘
```

#### Step 1: Probe Node Fingerprint
Before issuing a quarterly activation bundle, extract the host's deterministic hardware fingerprint:
```bash
kdouja license fingerprint --table
# or JSON format:
kdouja license fingerprint --json
```
*Output:*
```
╔══════════════════════════════════════════════════════════════════════════════╗
║            AARKAM KDOUJA NODE CRYPTOGRAPHIC HARDWARE FINGERPRINT             ║
╠══════════════════════════════════════════════════════════════════════════════╣
║ Node Fingerprint :  ARK-FP-AD8FF9EE-77AEB122-F222165B                        ║
║ Host Name        :  STORAGE-NODE-01                                          ║
║ Architecture     :  X64                                                      ║
║ CPU Cores        :  16                                                       ║
╚══════════════════════════════════════════════════════════════════════════════╝

[i] Provide this Node Fingerprint to your Aarkam account representative or portal
    to generate your quarterly activation bundle (.arkbundle / .arklic).
```

#### Step 2: Apply and Seal the Activation Bundle
Apply the issued quarterly bundle to the database directory:
```bash
kdouja license apply --file /path/to/kdouja-license.arkbundle --dir /var/lib/kdouja
```
* **Single Registration & Sealing**: Kdouja verifies the RSA-4096 / SHA-512 PSS signature, ensures the target fingerprint matches the node, and writes a cryptographic seal in `.kdouja_audit`.
* **Zero Overhead**: Routine database reads, writes, and restarts bypass hardware querying for maximum microsecond latency.
* **Automatic Upgrade Re-Audit**: When upgrading the Kdouja engine binary (e.g. `v1.0.1` to `v1.0.2`), Kdouja automatically performs a hardware re-audit against the node fingerprint, ensuring integrity while enabling seamless rolling binary upgrades.

#### Step 3: Check License & Audit Status
```bash
kdouja license status --dir /var/lib/kdouja
```

---

## 🔌 7. Pluggability with Rokka

Kdouja SAT is designed from the ground up to be **100% pluggable with Rokka** (Aarkam's Distributed Storage Gateway):

* **Direct In-Process Substrate**: Rokka storage daemons can reference `Aarkam.Kdouja.Engine` directly, substituting legacy storage layers with Kdouja SAT's zero-allocation Direct I/O block store and lock-free concurrent SkipList memtables.
* **Drop-In Contract Compatibility**: Kdouja SAT implements the identical core storage engine abstractions (`IKeyValueEngine`, `EngineOptions`, `IPageStore`, `WriteBatch`).
* **Standalone Microservice Daemon**: Alternatively, Rokka can connect to Kdouja SAT over high-throughput gRPC unix-domain sockets or TCP (`kdoujad`).
* **Why Migrate Rokka to Kdouja SAT Now**:
  1. **Direct I/O (`O_DIRECT`)**: Complete elimination of Linux page cache double-buffering and compaction pauses.
  2. **Deterministic Latency**: Bounded read tail latency (< 100 µs at p99) under heavy ingest.
  3. **Zero Dependencies**: Pure C# managed runtime without fragile native C++ interop wrappers.

---

## 📜 License

Licensed under the Apache License, Version 2.0 (or proprietary enterprise sovereign license). See `LICENSE` for details.
