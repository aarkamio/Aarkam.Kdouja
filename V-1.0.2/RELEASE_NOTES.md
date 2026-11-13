# Aarkam Kdouja Release Notes (Version kdouja-v1.0.2)

| Release Metadata | Specification |
| :--- | :--- |
| **Release Version** | `kdouja-v1.0.2 (General Availability)` |
| **Release Date** | November 2026 |
| **Product Line** | Aarkam Sovereign Data Fabric & Storage Engine Substrate |
| **Classification** | Official Engineering GA Release Notes |
| **Compliance Level** | Saudi NCA ECC-2:2024, FIPS 140-3 Zero-Trust Architecture |
| **Target Distribution** | Zero-Egress Air-Gapped Datacenters (Linux x64, Windows Server x64, Docker) |
| **Verification Baseline** | 1,006 / 1,006 Automated Tests Passing (100% Pass Rate) across .NET 8.0 & 10.0 |
| **Official Repository** | `https://github.com/aarkamio/Aarkam.Kdouja` |
| **Official Docker Image** | `https://hub.docker.com/r/aarkam/aarkam.kdouja` |

---

## 1. Executive Summary

**Aarkam Kdouja Version kdouja-v1.0.2** provides key enterprise hardening, full cryptographic licensing alignment with the Aarkam Sovereign Portal (`Aarkam.Website`), standardized CLI ergonomics (`kdouja`), an interactive administrative REPL shell, structured diagnostic logging via Serilog, and complete cross-platform environment variable symmetry across Docker containers, Linux distributions, and Windows Server hosts.

---

## 2. License Compatibility (Aarkam.Kdouja.SAT ↔ Aarkam.Website)

Verified full cryptographic and schema compatibility between `SovereignLicenseVerifier.cs` / `KdoujaLicenseManager.cs` and `Aarkam.Website`:

* **Cryptographic Keypair & Encryption**: Both repositories embed the exact same `OfficialAarkamRootPublicKeyBytes` (RSA-4096 / SHA-512 PSS) and `SovereignEntropySalt` (HMAC-SHA256 key derivation for AES-256-CBC).
* **Bundle & Certificate Format**: `Aarkam.Website` generates `.arkbundle` (`SovereignGenesisBundle` JSON with `signedLicensePem` and `targetClusterFingerprint`) and `.arklic` (PEM). `KdoujaLicenseManager.ApplyBundle` and `kdouja license apply --bundle <file.arkbundle> --dir <dataDir>` in `LicenseCommand.cs` consume both directly.
* **Hardware Fingerprint**: `NodeHardwareProfiler.GetNodeFingerprint()` in `NodeHardwareProfiler.cs` generates `ARK-FP-{HEX8}-{HEX8}-{HEX8}`, matching `Aarkam.Website`'s `ClusterFingerprint` binding.
* **Expiration Alignment Fix**: `AarkamIOLicenseGenerator.GenerateGenesisBundle` previously defaulted `expiresAt` to 1 year when `TrialDays == 0`. Updated `AarkamIOLicenseGenerator.cs` and `AarkamLicenseManagerService.cs` to forward `subscription.TrialEndsAtUtc ?? subscription.RenewalDateUtc` so quarterly (3-month) `.arkbundle` files carry the exact 90-day expiration.

---

## 3. CLI Standardization & Ergonomic Enhancements

* **Binary Name Standardized to `kdouja`**: Replaced legacy `kdouja-cli` with `kdouja` as the primary CLI executable across Windows, Linux, and Docker packages. Automatic backward-compatibility symlinks and wrappers (`kdouja-cli` and `kdouja-cli.cmd`) ensure zero disruption for existing automation.
* **Top-Level Operation Shortcuts**: Primary key-value operations can now be executed directly without requiring the `kv` subcommand prefix:
  - `kdouja put <key> <value>` (equivalent to `kdouja kv put`)
  - `kdouja get <key>` (equivalent to `kdouja kv get`)
  - `kdouja del <key>` / `kdouja delete <key>` (equivalent to `kdouja kv delete`)
  - `kdouja scan` (equivalent to `kdouja kv scan`)
* **Default Directory Auto-Resolution**: All commands (`put`, `get`, `del`, `scan`, `info`, `compact`, `bench`, `license`, `repl`) automatically resolve the active database directory from environment variables (`KDOUJA_BASE_DIRECTORY`, `KDOUJA_DATA_DIR`, `KDOUJA_DIR`) falling back to `./kdouja_data`, removing the need to specify `--dir` explicitly in containerized or configured environments.
* **SSTable Scan Directory Fix**: Fixed `InfoCommand` to scan `sstables/` (with fallback to legacy `sst/`), allowing `kdouja info --json` to correctly identify and report all committed SSTable files.

---

## 4. Interactive Administrative REPL Shell

* **Direct Execution Mode**: Launching `kdouja` with no command-line arguments (such as F5 in Visual Studio or double-clicking in File Explorer) or running `kdouja repl` / `kdouja shell` immediately enters an interactive administrative REPL shell.
* **Interactive Features**: Dynamic prompt reflecting current database directory (`kdouja (<dbname>)> `), shorthand tokenization, directory switching (`dir <path>`), screen clearing (`clear`/`cls`), in-memory session persistence, and clean EOF termination (`Ctrl+D` / `Ctrl+Z`).

---

## 5. Structured Serilog Diagnostic Logging Lifecycle

* **Channel Isolation for Automation**: Console diagnostic logs are routed exclusively to `stderr`, guaranteeing that `stdout` remains 100% clean and unpolluted for machine-readable formats (`--json`, `--yaml`, `--table`).
* **Noise Suppression**: Default console log level set to `Warning`, eliminating internal engine initialization/teardown chatter during standard point queries.
* **Diagnostic Flags & Switches**: Supports `--verbose` (`Verbose`), `--quiet` (`Error`), dynamic `--log-level <LEVEL>` (or `KDOUJA_LOG_LEVEL`), and daily rolling file logging via `--log-file <PATH>` (or `KDOUJA_LOG_FILE`).

---

## 6. Cross-Platform Environment Variable Symmetry

Full synchronization between the autonomous server daemon (`kdoujad`) and standalone CLI (`kdouja`) across Docker, Linux, and Windows:

| Variable | Scope | Description |
| :--- | :--- | :--- |
| `KDOUJA_BASE_DIRECTORY` | Daemon & CLI | Primary database root directory. Defaults to `/var/lib/kdouja` in Docker. |
| `KDOUJA_WAL_KEY` | Daemon & CLI | AES-256 WAL encryption key. Resolves hex or derives SHA-256 deterministically from database path. |
| `KDOUJA_MEMTABLE_FLUSH_MB` | Daemon & CLI | MemTable flush threshold in megabytes (default: 32MB). |
| `KDOUJA_ENABLE_DIRECT_IO` | Daemon & CLI | Kernel cache bypass (`O_DIRECT`). Flexible boolean parsing (`true`, `false`, `1`, `0`, `yes`, `no`). |
| `KDOUJA_ENABLE_WAL_FSYNC` | Daemon & CLI | Hardware write-ahead log fsync barrier (default: true). |
| `KDOUJA_LOG_LEVEL` | CLI | Serilog minimum log level switch. |
| `KDOUJA_LOG_FILE` | CLI | File sink path for daily rolling diagnostic log outputs. |

---

## 7. Storage Locking & Failure Boundary Resilience

* **Deterministic Conflict Exit Code**: `StorageLockException` (thrown when database is concurrently locked by another engine instance or `kdoujad`) is mapped directly to `ExitCodes.Conflict` (`10`) with descriptive suggested action:
  > *"Ensure no other Kdouja engine or daemon (kdoujad) process is actively accessing this directory."*
* **Domain Exception Hierarchy**: Structured `ErrorEnvelope` rendering across `DataCorruptionException` (exit code `13`), `StorageExhaustedException`, `CryptographicException`, and `TransactionConflictException`.

---

## 8. Package Contents & Verification Hashes

### Artifact Archives:
* **`kdouja-v1.0.2-linux-x64.zip`**: Linux server daemon (`kdoujad`), CLI (`kdouja`), automated installer (`install-kdouja.sh`), container entrypoint (`entrypoint.sh`), and runtime configurations.
* **`kdouja-v1.0.2-win-x64.zip`**: Windows distribution (`kdoujad.exe`, `kdouja.exe`, `kdouja-cli.cmd`), automated PowerShell installer (`install-kdouja.ps1`), and runtime configurations.
* **Docker Container**: `aarkam/aarkam.kdouja:v1.0.2` and `aarkam/aarkam.kdouja:latest`.

### SHA-256 Checksums (`SHA256SUMS.txt`):
```text
61b132de6a5539c7919746a2f8e999c3ce9b4b5142e86a27838403f2be54dcbe  kdouja-v1.0.2-linux-x64.zip
72d7f7ff034f6f131a5e284b95efe7ebe4ef059a891e14e474148f7442ff04f7  kdouja-v1.0.2-win-x64.zip
```
