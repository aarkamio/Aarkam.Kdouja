# Aarkam Kdouja Release Notes (Version kdouja-v1.0.3)

| Release Metadata | Specification |
| :--- | :--- |
| **Release Version** | `kdouja-v1.0.3 (General Availability)` |
| **Release Date** | November 2026 |
| **Product Line** | Aarkam Sovereign Data Fabric & Storage Engine Substrate |
| **Classification** | Official Engineering GA Release Notes |
| **Compliance Level** | Saudi NCA ECC-2:2024, FIPS 140-3 Zero-Trust Architecture |
| **Target Distribution** | Zero-Egress Air-Gapped Datacenters (Linux x64, Windows Server x64, Docker) |
| **Verification Baseline** | 519 / 519 Automated Tests Passing (100% Pass Rate) across .NET 8.0 & 10.0 |
| **Official Repository** | `https://github.com/aarkamio/Aarkam.Kdouja` |
| **Official Docker Image** | `https://hub.docker.com/r/aarkam/aarkam.kdouja:v1.0.3` |

---

## 1. Executive Summary

**Aarkam Kdouja Version kdouja-v1.0.3** delivers complete production installers and environment automation for both the **Kdouja Server Daemon (`kdoujad`)** and **Kdouja CLI (`kdouja` / `kdouja-cli`)**.

Engineered to operate either as an in-process embedded storage library or an autonomous network daemon, Kdouja provides bare-metal NVMe saturation, low Write Amplification, hardware-enforced AES-256 WAL durability, and enterprise-grade command-line tooling:

- **Automated Environment PATH Configuration**: Native Windows PowerShell installer (`install-kdouja.ps1`) and Linux installer (`install-kdouja.sh`) permanently add Kdouja to the system/user PATH and broadcast setting changes for immediate terminal access.
- **Dual-Substrate Architecture**: Decouples keys and small metadata into the LSM-tree while streaming large binary payloads (>64KB) directly into 256MB PageStore blocks.
- **Direct I/O Hardware Saturation**: Bypasses the host OS kernel page cache (`FILE_FLAG_NO_BUFFERING` on Windows, `O_DIRECT` on Linux) to prevent dirty-page thrashing.
- **Node Hardware Fingerprinting (`ARK-FP-...`)**: Deterministic multi-factor cryptographic hardware profiling required for issuing air-gapped activation bundles.
- **Single-Registration & Upgrade-Triggered Re-Auditing**: Binds the license once to the node hardware in `.kdouja_audit` for zero-overhead runtime execution, re-auditing only upon engine binary upgrade.
- **Autonomous Daemon & Service Provisioning**: Automated systemd service registration on Linux (`kdoujad.service`) and optional Windows Service registration on Windows (`KdoujaServer`).
- **Official Docker Image**: Published to Docker Hub at `aarkam/aarkam.kdouja:v1.0.3` and `latest`.

---

## 2. Competitive Positioning Matrix

| Feature / Metric | **Aarkam Kdouja** | **RocksDB** | **Pebble** | **BadgerDB** | **LMDB** | **SQLite** |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Runtime Substrate** | Modern .NET 8/10 Managed | C++17 Native | Go Managed | Go Managed | C Native | C Native |
| **Large Value Separation** | **Native 256MB PageStore** | Opt-in BlobDB | Experimental | Value Log | None | None |
| **Direct I/O (Bypass Cache)** | **Native (Windows & Linux)** | Complex tuning | No | No | No | No |
| **Write Amplification (WAF)**| **1.2x – 3.5x** | 10x – 30x | 10x – 25x | 2x – 4x | High (Copy-on-write)| High (B-Tree journal)|
| **Autonomous Daemon** | **Yes (`kdoujad`)** | None | None | None | None | None |
| **CLI & Environment Setup** | **Automated PATH & Tooling** | Manual tools | Manual tools | Manual tools | Basic CLI | Basic CLI |
| **Hardware-Bound Licensing**| **Node FP & Single-Seal** | None (OSS) | None (OSS) | None (OSS) | None (OSS) | None (OSS) |
| **WAL Hardware Encryption** | **Native AES-256** | Custom plugin | None | Native | None | Third-party extension|

---

## 3. Package Contents & Artifacts

* **`kdouja-v1.0.3-linux-x64.zip`**: Linux server daemon (`kdoujad`), CLI (`kdouja` / `kdouja-cli`), automated installer (`install-kdouja.sh`), runtime dependencies, and documentation.
* **`kdouja-v1.0.3-win-x64.zip`**: Windows server daemon (`kdoujad.exe`), CLI (`kdouja.exe` / `kdouja-cli.exe`), automated installer (`install-kdouja.ps1`), daemon launcher (`start-kdoujad.cmd`), and documentation.
* **`install-kdouja.sh`**: Standalone Linux production installation script.
* **`install-kdouja.ps1`**: Standalone Windows production installation script.
* **`SHA256SUMS.txt`**: Cryptographic integrity checksums for all release archives.
* **Docker Container**: `aarkam/aarkam.kdouja:v1.0.3` and `aarkam/aarkam.kdouja:latest`.

---

## 4. Verification Checksums

```text
b374ba912e78723656af07d61b0423e49fb7b9bbe2271900705daf9c249d3cae  kdouja-v1.0.3-linux-x64.zip
e2a3f60d281dd7d16492b5949410b99f345b717cd330710b479dd644647eb7d3  kdouja-v1.0.3-win-x64.zip
```
