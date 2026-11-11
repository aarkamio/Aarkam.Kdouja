# Aarkam Kdouja Release Notes (Version kdouja-v1.0.1)

| Release Metadata | Specification |
| :--- | :--- |
| **Release Version** | `kdouja-v1.0.1 (General Availability)` |
| **Release Date** | November 2026 |
| **Product Line** | Aarkam Sovereign Data Fabric & Storage Engine Substrate |
| **Classification** | Official Engineering GA Release Notes |
| **Compliance Level** | Saudi NCA ECC-2:2024, FIPS 140-3 Zero-Trust Architecture |
| **Target Distribution** | Zero-Egress Air-Gapped Datacenters (Linux x64, Windows Server x64, Docker) |
| **Verification Baseline** | 503 / 503 Automated Tests Passing (100% Pass Rate) across .NET 8.0 & 10.0 |
| **Official Repository** | `https://github.com/aarkamio/Aarkam.Kdouja` |
| **Official Docker Image** | `https://hub.docker.com/r/aarkam/aarkam.kdouja` |

---

## 1. Executive Summary

**Aarkam Kdouja Version kdouja-v1.0.1** marks the official standalone release of Aarkam's high-performance Log-Structured Merge-tree (LSM-tree) and physical Direct I/O storage engine.

Engineered to operate either as an in-process embedded storage library or an autonomous network daemon, Kdouja provides bare-metal NVMe saturation, low Write Amplification, hardware-enforced AES-256 WAL durability, and enterprise-grade command-line tooling:

- **Dual-Substrate Architecture**: Decouples keys and small metadata into the LSM-tree while streaming large binary payloads (>64KB) directly into 256MB PageStore blocks.
- **Direct I/O Hardware Saturation**: Bypasses the host OS kernel page cache (`FILE_FLAG_NO_BUFFERING` on Windows, `O_DIRECT` on Linux) to prevent dirty-page thrashing.
- **Zero-Allocation Modern .NET**: Implemented in clean managed C# with `Span<T>`, `Memory<T>`, and SIMD xxHash64 Bloom filters.
- **Enterprise CLI with System.CommandLine**: Standardized machine-readable outputs (`--json`, `--table`, `ErrorEnvelope`) with deterministic exit codes matching `AM.CLI`.
- **Autonomous Daemon (`kdoujad`)**: Built-in binary gRPC streaming daemon on port 57771.
- **Official Docker Image**: Published to Docker Hub at `aarkam/aarkam.kdouja:v1.0.1`.

---

## 2. Competitive Positioning

| Feature / Metric | **Aarkam Kdouja** | **RocksDB** | **Pebble** | **BadgerDB** | **LMDB** |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Runtime** | Modern .NET 8/10 | C++17 | Go | Go | C |
| **Large Value Separation** | **Yes** (256MB PageStore) | Opt-in BlobDB | Experimental | **Yes** (Value Log) | No |
| **Direct I/O** | **Native** | Complex setup | No | No | No |
| **Write Amplification** | **1.2x – 3.5x** | 10x – 30x | 10x – 25x | 2x – 4x | High |
| **Built-in Daemon** | **Yes** (`kdoujad`) | None | None | None | None |
| **Hardware Encryption** | **Native AES-256 WAL** | Custom plugin | None | Native | None |

---

## 3. Package Contents

* **`kdouja-v1.0.1-linux-x64.zip`**: Linux autonomous server daemon (`kdoujad`), CLI (`kdouja-cli`), installation script (`install-kdouja.sh`), and runtime configurations.
* **`kdouja-v1.0.1-win-x64.zip`**: Windows distribution (`kdoujad.exe`, `kdouja-cli.exe`), PowerShell installer (`install-kdouja.ps1`), and runtime configurations.
* **Docker Container**: `aarkam/aarkam.kdouja:v1.0.1` and `aarkam/aarkam.kdouja:latest`.

---

## 4. Licensing, Node Fingerprinting & Single-Registration Architecture

* **Autonomous 30-Day Evaluation**: Automatically initiates on node with zero egress required.
* **Quarterly Activation Bundles**: Cryptographically signed `.arkbundle` / `.arklic` files (RSA-4096 / SHA-512 PSS).
* **Node Fingerprint Extraction**: Extract host hardware fingerprint via `kdouja-cli license fingerprint` (`ARK-FP-XXXXXXXX-XXXXXXXX-XXXXXXXX`).
* **Single-Registration & Sealing**: When applied (`kdouja-cli license apply`), the license binds and seals once into `.kdouja_audit`. Routine operations bypass hardware audits for maximum throughput.
* **Upgrade-Triggered Re-Auditing**: When upgrading to a new engine version, Kdouja automatically re-audits the node hardware fingerprint and reseals the audit state.
