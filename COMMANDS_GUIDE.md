# Aarkam Kdouja CLI — Complete Commands Guide

> **Applies to:** `kdouja` / `kdouja-cli` (v1.0.3+)  
> **Runtime:** .NET 8.0 LTS & .NET 10.0 (`System.CommandLine`)  
> **Platforms:** Windows x64, Linux x64, macOS, Docker (`aarkam/aarkam.kdouja`)

This guide is the authoritative command-line reference for **Kdouja CLI (`kdouja`)** — the administrative, diagnostics, backup/recovery, integrity verification, data migration, licensing, and benchmarking tool for the **Aarkam.Kdouja** standalone LSM-Tree and Direct-I/O `.aarkam` PageStore storage engine.

> [!NOTE]
> On systems installed with `install-kdouja.ps1` (Windows) or `install-kdouja.sh` (Linux), both `kdouja` and `kdouja-cli` invoke the same binary and accept identical arguments. Both installers automatically choose the fastest non-OS storage partition (`NVMe → SSD → Virtual → HDD` with a 10 GB free-space guardrail) and export `KDOUJA_BASE_DIRECTORY` globally.

---

## Table of Contents

1. [Quick Reference Matrix](#1-quick-reference-matrix)
2. [Global Options & Output Formats](#2-global-options--output-formats)
3. [Zero-Trust Authentication Guard & Lock Behavior](#3-zero-trust-authentication-guard--lock-behavior)
4. [Authentication Commands (`auth`)](#4-authentication-commands-auth)
5. [Key-Value Operations (`kv` & Direct Shortcuts)](#5-key-value-operations-kv--direct-shortcuts)
6. [Engine Diagnostics & Metrics (`info` / `stats`)](#6-engine-diagnostics--metrics-info--stats)
7. [Live Daemon Health Probe (`health` / `ping`)](#7-live-daemon-health-probe-health--ping)
8. [Effective Configuration Inspector (`config`)](#8-effective-configuration-inspector-config)
9. [Storage Integrity Verification (`verify` / `check`)](#9-storage-integrity-verification-verify--check)
10. [Sovereign Backup & Restore (`backup` / `restore`)](#10-sovereign-backup--restore-backup--restore)
11. [Bulk Data Migration (`export` / `import`)](#11-bulk-data-migration-export--import)
12. [PageStore Secured Storage Inspector (`pages`)](#12-pagestore-secured-storage-inspector-pages)
13. [Manual Compaction (`compact`)](#13-manual-compaction-compact)
14. [Performance Benchmarking (`bench`)](#14-performance-benchmarking-bench)
15. [SSTable Physical Inspector (`dump-sst` / `sst`)](#15-sstable-physical-inspector-dump-sst--sst)
16. [Sovereign Licensing & Node Fingerprinting (`license`)](#16-sovereign-licensing--node-fingerprinting-license)
17. [Interactive REPL Shell (`repl` / `shell`)](#17-interactive-repl-shell-repl--shell)
18. [On-Disk Storage Layout & `.aarkam` Segments](#18-on-disk-storage-layout--aarkam-segments)
19. [Environment Variables Reference](#19-environment-variables-reference)
20. [Standardized Exit Codes](#20-standardized-exit-codes)
21. [Docker CLI Usage & Automation Recipes](#21-docker-cli-usage--automation-recipes)

---

## 1. Quick Reference Matrix

| Command | Aliases | Auth | Safe While `kdoujad` Runs? | Description |
| :--- | :--- | :---: | :---: | :--- |
| `kdouja` | — | No* | Yes | Launches interactive REPL shell when called with no arguments |
| `kdouja --version` | — | No | Yes | Prints clean semantic version (e.g. `1.0.3`) |
| `kdouja --help` | `-h`, `-?`, `/?` | No | Yes | Prints root or subcommand usage help |
| `kdouja auth login` | — | No | Yes | Authenticates operator session (password or Aarkam-issued PEM key) |
| `kdouja auth logout` | — | No | Yes | Invalidates and deletes `~/.kdouja/credentials.json` |
| `kdouja auth status` | — | No | Yes | Displays active session identity, tenant, roles, and token expiry |
| `kdouja auth whoami` | — | No | Yes | Prints authenticated username, tenant, and roles |
| `kdouja kv put` | `kdouja put` | Yes | **Yes** (Auto Daemon Bridge) | Inserts or updates a UTF-8 key-value record |
| `kdouja kv get` | `kdouja get` | Yes | **Yes** (Auto Daemon Bridge) | Retrieves a value by key |
| `kdouja kv delete` | `delete`, `del`, `kv del` | Yes | **Yes** (Auto Daemon Bridge) | Writes a deletion tombstone for a key |
| `kdouja kv scan` | `kdouja scan` | Yes | **Yes** (Auto Daemon Bridge) | Scans lexicographically ordered key-value records |
| `kdouja kv count` | — | Yes | **Yes** (Auto Daemon Bridge) | Counts keys and total value bytes in an optional range |
| `kdouja info` | `kdouja stats` | Yes | **Yes** (Live Daemon / RO) | Displays paths, metrics, SSTables, WAL, and `.aarkam` segments |
| `kdouja health` | `kdouja ping` | Yes | **Yes** (HTTP Probe) | Checks live `kdoujad` `/healthz`, latency, version, and license state |
| `kdouja config` | — | Yes | **Yes** (Lock-Free) | Displays resolved effective paths, env overrides, and engine tuning |
| `kdouja verify` | `kdouja check` | Yes | **Yes** (Read-Only) | Validates SSTables, WAL readability, `.aarkam` alignment, and license |
| `kdouja backup` | — | Yes | **Yes** (Read-Share) | Creates a SHA-256 verified `.zip` database backup archive |
| `kdouja restore` | — | Yes | Target must be idle | Verifies SHA-256 manifest and restores a backup archive |
| `kdouja export` | — | Yes | No (Exclusive Lock) | Streams key-value records to an NDJSON file |
| `kdouja import` | — | Yes | No (Exclusive Lock) | Bulk-imports NDJSON records via atomic `WriteBatch` commits |
| `kdouja pages list` | — | Yes | **Yes** (Lock-Free) | Lists `.aarkam` PageStore segments, sizes, and 512B alignment |
| `kdouja compact` | — | Yes | **Yes** (Auto Daemon Bridge) | Triggers a manual SSTable merge compaction pass |
| `kdouja bench` | — | Yes | Uses own `--dir` | Runs parallel write ingestion and point-lookup benchmarks |
| `kdouja dump-sst` | `kdouja sst` | Yes | **Yes** (Read-Only) | Inspects an individual `.sst` file's level and key boundaries |
| `kdouja license status` | — | No | **Yes** (Lock-Free) | Inspects license state, trial expiry, node lock, and audit seal |
| `kdouja license fingerprint` | `probe`, `node-id` | No | **Yes** (Lock-Free) | Extracts deterministic hardware Node Fingerprint (`ARK-FP-...`) |
| `kdouja license apply` | — | No | **Yes** | Registers and seals an Aarkam-signed `.arkbundle` / `.arklic` |
| `kdouja license reaudit` | — | No | **Yes** | Re-audits node hardware against registered license and reseals |
| `kdouja license inspect` | — | No | **Yes** (Offline) | Verifies a license bundle offline and checks node compatibility |
| `kdouja repl` | `shell`, `interactive` | Yes | Depends on command | Starts the interactive administrative REPL shell |

*\*Running `kdouja` with no arguments enters the REPL immediately; protected commands inside the REPL still enforce authentication.*

---

## 2. Global Options & Output Formats

All global options are **recursive** and can be placed before or after any subcommand.

| Option | Short / Alias | Type | Default | Description |
| :--- | :--- | :--- | :--- | :--- |
| `--json` | — | `bool` | `false` | Output results as indented JSON |
| `--yaml` | — | `bool` | `false` | Output results as YAML |
| `--table` | — | `bool` | `false` | Format output as an aligned terminal table (default) |
| `--output-format` | `--format` | `enum` | `null` | Explicit format: `Table`, `Json`, `Yaml`, `Ndjson`, or `Csv` |
| `--output` | `-o` | `FILE` | `null` | Write command output to the specified file path instead of `stdout` |
| `--verbose` | `-v` | `bool` | `false` | Enable verbose diagnostic logging and payload timings |
| `--quiet` | `-q` | `bool` | `false` | Suppress headers, banners, and non-essential status messages |
| `--timeout` | `-t` | `int` | `30` | Maximum operation execution timeout in seconds |
| `--log-file` | `-l` | `FILE` | `null` | Write structured Serilog diagnostic logs to the specified file path |
| `--log-level` | — | `LEVEL` | `null` | Minimum log level: `Verbose`, `Debug`, `Information`, `Warning`, `Error`, `Fatal` |
| `--help` | `-h`, `-?`, `/?` | — | — | Show help and usage information for the command |
| `--version` | — | — | — | Show the clean semantic CLI version (e.g. `1.0.3`) and exit |

### Format Resolution Precedence

1. `--output-format` / `--format` (highest priority)
2. `--json`
3. `--yaml`
4. `--table` (default when no format flag is specified)

### Examples

```bash
# Export engine diagnostics as JSON to a file
kdouja info --json -o ./reports/engine-info.json

# Stream scanned records as newline-delimited JSON (NDJSON)
kdouja scan --start "user:" --limit 500 --format Ndjson

# Export scanned keys to CSV
kdouja scan --start "user:" --output-format Csv -o ./users.csv

# Run compaction with debug logging persisted to a log file
kdouja compact --dir /mnt/nvme/aarkam/kdouja --verbose --log-level Debug --log-file ./compact.log
```

---

## 3. Zero-Trust Authentication Guard & Lock Behavior

### Preflight Authentication Guard
Kdouja CLI enforces an active operator session before running any protected command. Only the following are exempt:
- `auth` (`login`, `logout`, `status`, `whoami`)
- `license` (`status`, `fingerprint`, `apply`, `reaudit`, `inspect`)
- Help and version flags (`--help`, `-h`, `-?`, `/?`, `--version`, `-v`)
- REPL meta commands (`help`, `version`, `exit`, `quit`, `q`, `clear`, `cls`)

Unauthenticated invocations exit with code `3` (`AuthenticationFailure`) and, under `--json` / `--yaml`, emit a structured `ErrorEnvelope`:

```json
{
  "success": false,
  "error": {
    "code": "AUTH_REQUIRED",
    "message": "Authentication Required: You are not currently logged in.",
    "suggestedAction": "Execute 'kdouja auth login --username <user>' to establish an operator session."
  }
}
```

### Session Storage & Security
- **Credential Store:** `~/.kdouja/credentials.json` (`%USERPROFILE%\.kdouja\credentials.json` on Windows), encrypted at rest with **AES-256-GCM** using a key derived from the host Node Fingerprint, OS username, and machine name (`0600` permissions on Linux/macOS).
- **Operator Registry:** `~/.kdouja/operators.json`, storing salted **PBKDF2-SHA512** (100,000 iterations) hashes.
- **Session Tokens:** Node-bound `kdj_v1_...` tokens valid for **7 days**.
- **CI/CD Headless Override:** Set `KDOUJA_TOKEN` (≥ 12 characters; cannot be `none`, `null`, or `anonymous`) to authenticate non-interactively.

### Exclusive `DirectoryLock` vs. Lock-Safe Commands
When the autonomous daemon (`kdoujad` / `KdoujaServer` Windows Service / `kdoujad.service` systemd unit) is running, it holds an exclusive OS file lock on `<BaseDirectory>\LOCK` to prevent multi-process LSM corruption.
- **Always safe while `kdoujad` is running:** `health`, `info`, `config`, `verify`, `backup`, `pages list`, `dump-sst`, `license *`, `auth *`.
- **Requires direct exclusive engine access (stop daemon first or target an offline directory):** `kv put/get/delete/scan/count`, `compact`, `export`, `import`.

---

## 4. Authentication Commands (`auth`)

Manage operator authentication, zero-trust session tokens, and identity context.

### `kdouja auth login`
Authenticates an operator using either username/password or an Aarkam-issued PEM private key and writes the encrypted local session.

**Syntax:**
```bash
kdouja auth login --username <USER> [--password <PASS>] [--tenant <TENANT>] [--key-file <PEM>] [--endpoint <URL>]
```

**Options:**

| Option | Short | Required | Default | Description |
| :--- | :--- | :---: | :--- | :--- |
| `--username` | `-u` | Yes | — | Operator username |
| `--password` | `-p` | No | *(masked prompt)* | Operator password. Prompts with `*` masking when omitted interactively |
| `--tenant` | `-t` | No | `system` | Tenant context identifier |
| `--key-file` | `-k` | No | — | Path to an Aarkam-issued PKCS#8 or RSA PEM private key |
| `--endpoint` | `-e` | No | `KDOUJA_ENDPOINT` or `http://localhost:57771` | Kdouja server daemon endpoint |

**Behavior & Role Assignment:**
- First-time password registration on a node (or usernames `admin` / `root`) receives `ClusterAdmin`, `StorageOperator`, `AuthorityOfficer`. Other new password operators receive `StorageOperator`.
- PEM private-key logins verify RSA key validity and receive `ClusterAdmin`, `StorageOperator`, `AuthorityOfficer`.

**Error Codes:** `INVALID_ARGUMENTS` (`2`), `CREDENTIALS_REQUIRED` (`3`), `AUTH_FAILED` (`3`), `INVALID_KEY_FILE` (`3`), `KEY_FILE_NOT_FOUND` (`9`).

**Examples:**
```bash
kdouja auth login --username admin
kdouja auth login -u ops-lead -p "S3cur3P@ss!" --tenant prod-riyadh --json
kdouja auth login -u node-admin --key-file /etc/aarkam/operator.key
```

---

### `kdouja auth logout`
Invalidates the active operator session and deletes `~/.kdouja/credentials.json`.

```bash
kdouja auth logout
kdouja auth logout --json
```

---

### `kdouja auth status`
Displays the active operator session, tenant, assigned roles, daemon endpoint, and authentication/expiration timestamps in both UTC and local timezone.

```bash
kdouja auth status
kdouja auth status --json
```

---

### `kdouja auth whoami`
Prints a single-line summary of the authenticated identity (`anonymous` when not logged in).

```bash
kdouja auth whoami
# Output: admin (tenant: system, roles: [ClusterAdmin, StorageOperator, AuthorityOfficer])
```

---

## 5. Key-Value Operations (`kv` & Direct Shortcuts)

Perform direct LSM-Tree CRUD, range scan, and key counting against a local Kdouja database directory.

> [!TIP]
> Top-level shortcuts are available for the four primary operations:
> `kdouja put` ≡ `kdouja kv put` · `kdouja get` ≡ `kdouja kv get` · `kdouja delete` / `kdouja del` ≡ `kdouja kv delete` · `kdouja scan` ≡ `kdouja kv scan`.

### `kdouja put` / `kdouja kv put`
Writes or updates a UTF-8 key-value pair. Appends to the encrypted WAL first, then inserts into the active SkipList MemTable, returning the committed sequence number.

**Syntax:**
```bash
kdouja put <key> <value> [--dir <PATH>] [--sync]
```

| Name | Short | Required | Default | Description |
| :--- | :--- | :---: | :--- | :--- |
| `<key>` | — | Yes | — | Database key (UTF-8) |
| `<value>` | — | Yes | — | Value payload (UTF-8) |
| `--dir` | `-d` | No | Resolved `BaseDirectory` | Target database directory |
| `--sync` | — | No | `false` | Force hardware `fsync` on WAL commit |

**JSON Schema:** `{ "key": "...", "valueSizeBytes": 9, "sequenceNumber": 42 }`

---

### `kdouja get` / `kdouja kv get`
Performs a point lookup across MemTable → Immutable MemTable → L0..L6 SSTables (accelerated by SIMD xxHash64 Bloom filters).

**Syntax:**
```bash
kdouja get <key> [--dir <PATH>]
```

**Error Codes:** `KEY_NOT_FOUND` (exit code `9`) if the key does not exist or has a deletion tombstone.  
**JSON Schema:** `{ "key": "...", "value": "...", "valueSizeBytes": 9 }`

---

### `kdouja delete` / `kdouja del` / `kdouja kv delete`
Appends a deletion tombstone record to the WAL and MemTable. Physical bytes are reclaimed during subsequent SSTable compaction (`kdouja compact`).

**Syntax:**
```bash
kdouja delete <key> [--dir <PATH>] [--sync]
```

**JSON Schema:** `{ "key": "...", "sequenceNumber": 43 }`

---

### `kdouja scan` / `kdouja kv scan`
Iterates over keys in lexicographical UTF-8 byte order between optional inclusive bounds.

**Syntax:**
```bash
kdouja scan [--dir <PATH>] [--start <KEY>] [--end <KEY>] [--limit <N>]
```

| Option | Short | Required | Default | Description |
| :--- | :--- | :---: | :--- | :--- |
| `--dir` | `-d` | No | Resolved `BaseDirectory` | Database directory |
| `--start` | `-s` | No | *(beginning)* | Inclusive start key |
| `--end` | `-e` | No | *(unbounded)* | Inclusive end key |
| `--limit` | `-n` | No | `100` | Maximum records to return |

---

### `kdouja kv count`
Counts matching keys and aggregates total value bytes across an optional inclusive key range without printing values to the console.

**Syntax:**
```bash
kdouja kv count [--dir <PATH>] [--start <KEY>] [--end <KEY>]
```

**Examples:**
```bash
kdouja kv count --start "user:" --end "user:~"
kdouja kv count --dir /mnt/nvme/aarkam/kdouja --json
```

**JSON Schema:**
```json
{
  "databasePath": "F:\\Aarkam\\Kdouja\\data",
  "startKey": "user:",
  "endKey": "user:~",
  "keyCount": 1420,
  "totalValueBytes": 184320
}
```

---

## 6. Engine Diagnostics & Metrics (`info` / `stats`)

Displays base directory paths, lock state, runtime engine metrics, SSTables, WAL segments, and `.aarkam` PageStore segments.

**Lock-Safe Behavior:**
- When no daemon is holding the directory lock, `kdouja info` opens the engine directly and reports full live metrics (sequence number, MemTable sizing, WAF/RAF, Bloom filter intercept rate).
- When `kdoujad` (`KdoujaServer`) is actively running and holds `DirectoryLock`, `kdouja info` **automatically falls back to lock-free Read-Only Inspection** (`daemonActive: true`) — displaying `BaseDirectory`, `PagesDirectory`, file counts, on-disk footprint, and every `.sst`, `.wal`, and `.aarkam` file with exit code `0`.

**Syntax:**
```bash
kdouja info [--dir <PATH>] [--detailed]
kdouja stats [--dir <PATH>] [--detailed]
```

| Option | Short | Required | Default | Description |
| :--- | :--- | :---: | :--- | :--- |
| `--dir` | `-d` | No | Resolved `BaseDirectory` | Database directory |
| `--detailed` | — | No | `false` | List all `.sst` files even when more than 10 exist |

**Sample Output (While Daemon Is Running):**
```text
================================================================================
  Aarkam.Kdouja Engine Diagnostics — F:\Aarkam\Kdouja\data
================================================================================
  Base Data Directory         : F:\Aarkam\Kdouja\data
  PageStore (.aarkam) Dir     : F:\Aarkam\Kdouja\data\pages
  Storage Lock Status         : Active Daemon Running (Read-Only Inspection)
  Active SSTable Files        : 4
  WAL Segment Files           : 1
  PageStore (.aarkam) Files   : 2
  On-Disk Storage Footprint   : 545,259,520 bytes (520.00 MB)

  PageStore Secured Storage Segments (.aarkam) (2):
    • segment_00000000.aarkam      256.00 MB  (modified: 2026-11-26 02:10)
    • segment_00000001.aarkam      256.00 MB  (modified: 2026-11-26 02:25)
```

---

## 7. Live Daemon Health Probe (`health` / `ping`)

Probes a running `kdoujad` daemon over HTTP (`/healthz` and `/`) to verify liveness, measure round-trip latency, and retrieve daemon version, engine write/read-only state, and active license summary. Never touches disk locks.

**Syntax:**
```bash
kdouja health [--endpoint <URL>] [--timeout <SEC>]
kdouja ping [--endpoint <URL>]
```

| Option | Short | Required | Default | Description |
| :--- | :--- | :---: | :--- | :--- |
| `--endpoint` | `-e` | No | `KDOUJA_ENDPOINT` or `http://localhost:57771` | Target `kdoujad` HTTP/gRPC base URL |

**Exit Codes:**
- `0` — Daemon responded healthy (`HTTP 2xx`)
- `5` (`NetworkFailure`, `DAEMON_UNREACHABLE`) — Connection refused or host unreachable
- `6` (`Timeout`, `HEALTH_TIMEOUT`) — Probe exceeded `--timeout`
- `8` (`ClusterUnhealthy`) — Daemon responded with non-2xx health status

**Examples:**
```bash
kdouja health
kdouja ping --endpoint http://10.20.30.11:57771 --timeout 5 --json
```

**Sample JSON Output:**
```json
{
  "endpoint": "http://localhost:57771",
  "healthy": true,
  "httpStatusCode": 200,
  "latencyMs": 3.42,
  "healthMessage": "Healthy",
  "daemonVersion": "1.0.3",
  "daemonStatus": "Healthy",
  "licenseStatus": "Active",
  "licenseTier": "Quarterly Subscription",
  "nodeFingerprint": "ARK-FP-AD8FF9EE-77AEB122-F222165B"
}
```

---

## 8. Effective Configuration Inspector (`config`)

Resolves and prints the effective CLI and storage engine configuration — including **exactly which source** (CLI flag, environment variable, or default) provided `BaseDirectory` — without opening or locking the database.

**Syntax:**
```bash
kdouja config [--dir <PATH>]
```

| Option | Short | Required | Default | Description |
| :--- | :--- | :---: | :--- | :--- |
| `--dir` | `-d` | No | *(auto-resolved)* | Optional directory override to preview resolved subpaths |

**Security Note:** `kdouja config` never prints raw WAL encryption keys or session tokens; it reports only whether an environment override is active (`Environment Variable (Configured)` vs `Deterministic Path Key (Default)`).

**Examples:**
```bash
kdouja config
kdouja config --json
```

---

## 9. Storage Integrity Verification (`verify` / `check`)

Performs a read-only storage integrity audit across the database directory:
1. Checks every `.sst` file for zero-byte truncation; with `--deep`, opens each file via `SSTableReader.Open` to validate headers, footers, and key-boundary metadata.
2. Verifies readability of every `.wal` segment in `wal/` (using `FileShare.ReadWrite`, safe while `kdoujad` is running).
3. Verifies every `.aarkam` PageStore segment in `pages/` is non-empty and **512-byte sector aligned** for Direct I/O.
4. Evaluates the license and cryptographic audit seal state.

**Syntax:**
```bash
kdouja verify [--dir <PATH>] [--deep]
kdouja check [--dir <PATH>] [--deep]
```

| Option | Short | Required | Default | Description |
| :--- | :--- | :---: | :--- | :--- |
| `--dir` | `-d` | No | Resolved `BaseDirectory` | Database directory to verify |
| `--deep` | — | No | `false` | Structurally open and validate every `.sst` reader header/footer |

**Exit Codes:** `0` if all checks pass; `13` (`DataIntegrityFailure`) if any integrity issue is found; `9` (`DIRECTORY_NOT_FOUND`) if `--dir` does not exist.

**Examples:**
```bash
kdouja verify
kdouja verify --dir F:\Aarkam\Kdouja\data --deep --json
```

---

## 10. Sovereign Backup & Restore (`backup` / `restore`)

Creates and restores cryptographically verified point-in-time `.zip` backups with an embedded `BACKUP_MANIFEST.json` containing per-file **SHA-256** digests.

### `kdouja backup`
Packages `sstables/`, `wal/`, `pages/*.aarkam`, `CURRENT`, `MANIFEST*`, and (by default) license/audit seal files into a `.zip` archive while automatically excluding lock files (`LOCK`, `*.lock`).

**Syntax:**
```bash
kdouja backup --dest <ARCHIVE.zip> [--dir <PATH>] [--include-license <true|false>]
```

| Option | Aliases | Required | Default | Description |
| :--- | :--- | :---: | :--- | :--- |
| `--dest` | `-f`, `--to` | Yes | — | Destination `.zip` archive path (`.zip` appended if omitted) |
| `--dir` | `-d` | No | Resolved `BaseDirectory` | Source database directory |
| `--include-license` | — | No | `true` | Include `kdouja.license`, `.kdouja_audit`, and `.kdouja_init` |

> [!TIP]
> For strict point-in-time consistency on high-write production nodes, pause writes or briefly stop `KdoujaServer` before running `kdouja backup`.

**Example:**
```bash
kdouja backup --dir F:\Aarkam\Kdouja\data --dest D:\Backups\kdouja-2026-11-26.zip --json
```

---

### `kdouja restore`
Reads `BACKUP_MANIFEST.json`, blocks path-traversal entries, extracts every file, and verifies every file's **SHA-256** hash against the manifest.

**Syntax:**
```bash
kdouja restore --from <ARCHIVE.zip> [--dir <PATH>] [--force] [--verify-only]
```

| Option | Short | Required | Default | Description |
| :--- | :--- | :---: | :--- | :--- |
| `--from` | `-f` | Yes | — | Source backup `.zip` archive |
| `--dir` | `-d` | No | Resolved `BaseDirectory` | Target directory to restore into |
| `--force` | — | No | `false` | Allow restoring into a non-empty target directory |
| `--verify-only` | — | No | `false` | Verify all SHA-256 checksums in the archive without extracting |

**Error Codes:** `ARCHIVE_NOT_FOUND` (`9`), `TARGET_NOT_EMPTY` (`10`), `MANIFEST_MISSING` / `CHECKSUM_MISMATCH` / `PATH_TRAVERSAL_BLOCKED` (`13`).

**Examples:**
```bash
# Dry-run cryptographic verification of a backup archive
kdouja restore --from D:\Backups\kdouja-2026-11-26.zip --verify-only

# Restore into a fresh recovery directory
kdouja restore --from D:\Backups\kdouja-2026-11-26.zip --dir F:\Aarkam\Kdouja\restored --json
```

---

## 11. Bulk Data Migration (`export` / `import`)

Stream key-value records out to portable newline-delimited JSON (`NDJSON`) and bulk-load them back using atomic `WriteBatch` commits.

### `kdouja export`

**Syntax:**
```bash
kdouja export --file <OUT.ndjson> [--dir <PATH>] [--start <KEY>] [--end <KEY>] [--limit <N>]
```

| Option | Short | Required | Default | Description |
| :--- | :--- | :---: | :--- | :--- |
| `--file` | `-f` | Yes | — | Output NDJSON file path |
| `--dir` | `-d` | No | Resolved `BaseDirectory` | Source database directory |
| `--start` | `-s` | No | *(beginning)* | Inclusive start key |
| `--end` | `-e` | No | *(unbounded)* | Inclusive end key |
| `--limit` | `-n` | No | `0` *(unlimited)* | Maximum number of records to export |

**Output File Format (one JSON object per line):**
```json
{"key":"user:1001","value":"{\"name\":\"Alice\"}"}
{"key":"user:1002","value":"{\"name\":\"Bob\"}"}
```

---

### `kdouja import`

**Syntax:**
```bash
kdouja import --file <IN.ndjson> [--dir <PATH>] [--batch-size <N>]
```

| Option | Short | Required | Default | Description |
| :--- | :--- | :---: | :--- | :--- |
| `--file` | `-f` | Yes | — | Input NDJSON file path |
| `--dir` | `-d` | No | Resolved `BaseDirectory` | Target database directory |
| `--batch-size` | `-b` | No | `1000` | Records committed per atomic `WriteBatch` |

**Example:**
```bash
kdouja export --start "tenant:riyadh:" --end "tenant:riyadh:~" --file ./riyadh.ndjson
kdouja import --file ./riyadh.ndjson --dir F:\Aarkam\Kdouja\staging --batch-size 2000
```

---

## 12. PageStore Secured Storage Inspector (`pages`)

Inspects the physical 256 MB Direct-I/O PageStore segment files (`segment_XXXXXXXX.aarkam`) located in `<BaseDirectory>/pages`. Completely lock-free and safe while `kdoujad` is running.

### `kdouja pages list`

**Syntax:**
```bash
kdouja pages list [--dir <PATH>]
```

| Option | Short | Required | Default | Description |
| :--- | :--- | :---: | :--- | :--- |
| `--dir` | `-d` | No | Resolved `BaseDirectory` | Database directory |

**Sample Output:**
```text
================================================================================
  Aarkam.Kdouja PageStore (.aarkam) Segments — F:\Aarkam\Kdouja\data\pages
================================================================================
  Total Segments : 2
  Total Size     : 536,870,912 bytes (512.00 MB)

    • segment_00000000.aarkam      256.00 MB  [512B-Aligned]  (modified: 2026-11-26 02:10)
    • segment_00000001.aarkam      256.00 MB  [512B-Aligned]  (modified: 2026-11-26 02:25)
```

---

## 13. Manual Compaction (`compact`)

Forces a synchronous SSTable merge compaction pass to consolidate LSM levels, drop superseded key versions, and physically reclaim space from deletion tombstones.

**Syntax:**
```bash
kdouja compact [--dir <PATH>]
```

| Option | Short | Required | Default | Description |
| :--- | :--- | :---: | :--- | :--- |
| `--dir` | `-d` | No | Resolved `BaseDirectory` | Database directory |

**JSON Schema:** `{ "databasePath": "...", "sstablesBefore": 12, "sstablesAfter": 3, "elapsedMilliseconds": 342 }`

---

## 14. Performance Benchmarking (`bench`)

Executes a two-phase multi-threaded embedded engine benchmark:
1. **Parallel Write Ingestion:** Writes `--ops` random 128-byte payloads across `--threads` worker tasks.
2. **Parallel Point Lookups:** Reads back every written key across `--threads` worker tasks.

**Syntax:**
```bash
kdouja bench [--dir <PATH>] [--ops <N>] [--threads <T>] [--clean]
```

| Option | Short | Required | Default | Description |
| :--- | :--- | :---: | :--- | :--- |
| `--dir` | `-d` | No | `./bench_data` | Benchmark database directory |
| `--ops` | `-n` | No | `25000` | Total operations per phase |
| `--threads` | `-t` | No | `max(2, CPU_CORES / 2)` | Parallel worker task count |
| `--clean` | — | No | `false` | Delete benchmark directory before starting |

**Example:**
```bash
kdouja bench --dir F:\Aarkam\bench --ops 100000 --threads 8 --clean --json
```

---

## 15. SSTable Physical Inspector (`dump-sst` / `sst`)

Opens an individual physical `.sst` file on disk (read-only) and inspects its LSM level, file size, and smallest/largest key boundaries.

**Syntax:**
```bash
kdouja dump-sst <file>
kdouja sst <file>
```

**Example:**
```bash
kdouja dump-sst F:\Aarkam\Kdouja\data\sstables\sst_000001.sst --json
```

---

## 16. Sovereign Licensing & Node Fingerprinting (`license`)

Manages air-gapped Aarkam Sovereign Enterprise licensing, the 30-day Community Evaluation trial, deterministic node hardware fingerprinting (`ARK-FP-...`), single-registration bundle sealing, and upgrade hardware re-auditing.

> [!NOTE]
> All `license` subcommands are **exempt** from operator authentication so nodes can be provisioned before operator accounts exist. Only the Aarkam Website/Portal can sign valid `.arkbundle` / `.arklic` files.

### `kdouja license fingerprint` (aliases: `probe`, `node-id`)
Extracts the host's deterministic `ARK-FP-{8}-{8}-{8}` Node Fingerprint (aligned identically with Aarkam Rokka and AM CLI across both Windows and Linux).

```bash
kdouja license fingerprint --table
kdouja license fingerprint --json
```

### `kdouja license inspect`
Cryptographically verifies an Aarkam-signed `.arkbundle` / `.arklic` file offline (RSA-4096 / SHA-512 PSS) and checks node compatibility (`MATCH`, `UNBOUND`, or `MISMATCH`).

```bash
kdouja license inspect --bundle ./kdouja-license.arklic --json
```

### `kdouja license apply`
Verifies, registers, and seals an Aarkam-signed activation bundle into `<BaseDirectory>/kdouja.license` and `.kdouja_audit`.

```bash
kdouja license apply --bundle ./kdouja-license.arklic --dir F:\Aarkam\Kdouja\data
```

| Option | Aliases | Required | Default | Description |
| :--- | :--- | :---: | :--- | :--- |
| `--bundle` | `-b`, `--file`, `-f` | Yes | — | Path to `.arkbundle` or `.arklic` activation file |
| `--dir` | `-d` | No | Resolved `BaseDirectory` | Target database directory |

### `kdouja license status`
Displays current license state (`TrialActive`, `Active`, `InGracePeriod`, `Expired`, `Invalid`), tier, days remaining, node fingerprint, hardware lock, and audit seal status.

```bash
kdouja license status --dir F:\Aarkam\Kdouja\data --json
```

### `kdouja license reaudit`
Re-audits the current host hardware against the registered license and refreshes `.kdouja_audit` (pass `--force` to re-audit even when the engine version has not changed).

```bash
kdouja license reaudit --dir F:\Aarkam\Kdouja\data --force
```

---

## 17. Interactive REPL Shell (`repl` / `shell`)

Launches an interactive administrative shell with session-scoped `dir` state, live `(username | directory)` prompt, shorthand normalization, and full support for all global format flags (`--json`, `--yaml`, `--table`).

```bash
kdouja
kdouja repl --dir F:\Aarkam\Kdouja\data
```

**Built-In REPL Meta Commands:** `help` / `?`, `dir [path]`, `clear` / `cls`, `exit` / `quit` / `q`.  
**Shorthand Normalizations:** `put`/`get`/`del`/`delete`/`scan` → `kv <verb>`, `fingerprint`/`probe`/`node-id` → `license fingerprint`, `sst` → `dump-sst`. Active `--dir` is injected automatically for all directory-scoped commands (`info`, `config`, `verify`, `backup`, `restore`, `export`, `import`, `pages list`, `compact`, `bench`, `kv *`, `license status|apply|reaudit`).

---

## 18. On-Disk Storage Layout & `.aarkam` Segments

```text
<BaseDirectory>/                     # Auto-placed on fastest non-OS partition (e.g. F:\Aarkam\Kdouja\data)
├── pages/
│   ├── segment_00000000.aarkam      # 256 MB Direct-I/O PageStore secured storage segments
│   └── segment_00000001.aarkam
├── wal/
│   └── *.wal                        # AES-256 encrypted Write-Ahead Log segments
├── sstables/
│   └── *.sst                        # Flushed & compacted LSM-Tree SSTables (L0..L6)
├── CURRENT / MANIFEST-*             # LSM-Tree version set metadata
├── LOCK                             # Exclusive DirectoryLock held by active engine/daemon
├── kdouja.license                   # Activated Aarkam Sovereign license bundle
├── .kdouja_audit                    # Cryptographic hardware audit seal
└── .kdouja_init                     # 30-day evaluation anchor marker
```

---

## 19. Environment Variables Reference

| Variable | Fallback / Alias | Default | Description |
| :--- | :--- | :--- | :--- |
| `KDOUJA_BASE_DIRECTORY` | `KDOUJA_DATA_DIR`, `KDOUJA_DIR` | `./kdouja_data` | Default database directory when `--dir` is omitted |
| `KDOUJA_WAL_KEY` | `KDOUJA_WAL_ENCRYPTION_KEY`, `KDOUJA__WALKEY` | *(SHA-256 of full dir)* | 64-char hex AES-256 key (or passphrase hashed via SHA-256) |
| `KDOUJA_MEMTABLE_FLUSH_MB` | — | `32` (`64` in Docker) | MemTable flush threshold in MiB |
| `KDOUJA_ENABLE_DIRECT_IO` | — | `false` (`true` in Docker) | Enable Direct I/O write-through on `.aarkam` PageStore |
| `KDOUJA_ENABLE_WAL_FSYNC` | — | `true` | Force hardware `fsync` on WAL commits |
| `KDOUJA_PAGE_SIZE_BYTES` | — | `4096` | 4 KB sector-aligned PageStore allocation size |
| `KDOUJA_TOKEN` | — | *(none)* | Headless session token override (≥ 12 chars) for CI/CD |
| `KDOUJA_USER` | — | `service-account` | Operator username reported with `KDOUJA_TOKEN` |
| `KDOUJA_TENANT` | — | `system` | Tenant namespace reported with `KDOUJA_TOKEN` |
| `KDOUJA_ENDPOINT` | — | `http://localhost:57771` | Default `kdoujad` server daemon endpoint |

---

## 20. Standardized Exit Codes

| Exit Code | Constant | Meaning |
| :---: | :--- | :--- |
| `0` | `Success` | Command executed successfully |
| `1` | `GeneralFailure` | Generic or unhandled command failure |
| `2` | `InvalidArguments` | Invalid/missing CLI arguments, NDJSON parse error, or invalid license |
| `3` | `AuthenticationFailure` | Not logged in, invalid password, or invalid PEM private key |
| `4` | `AuthorizationDenied` | Security or permission violation |
| `5` | `NetworkFailure` | Daemon unreachable or transport connection failure |
| `6` | `Timeout` | Operation exceeded `--timeout` |
| `8` | `ClusterUnhealthy` | Daemon health check returned unhealthy status |
| `9` | `ResourceNotFound` | Key, file, directory, archive, or bundle not found |
| `10` | `Conflict` | State conflict (e.g. non-empty restore target without `--force`) |
| `12` | `OperationCancelled` | Operation cancelled by operator (`Ctrl+C`) or signal |
| `13` | `DataIntegrityFailure` | Checksum mismatch, bitrot detected, or `verify` / `restore` integrity failure |

---

## 21. Docker CLI Usage & Automation Recipes

### Recipe A: Check Daemon Health & Diagnostics
```bash
export KDOUJA_TOKEN="kdj_v1_prod_automation_token_9876543210"
docker run --rm --network host -e KDOUJA_TOKEN aarkam/aarkam.kdouja:v1.0.3 health --json
docker run --rm -e KDOUJA_TOKEN -v /mnt/nvme/aarkam/kdouja:/var/lib/kdouja aarkam/aarkam.kdouja:v1.0.3 info --json
```

### Recipe B: Nightly Integrity Check & Verified Backup
```bash
export KDOUJA_TOKEN="kdj_v1_prod_automation_token_9876543210"

# 1. Verify storage integrity (exit 0 = clean, exit 13 = corruption)
docker run --rm -e KDOUJA_TOKEN \
  -v /mnt/nvme/aarkam/kdouja:/var/lib/kdouja \
  aarkam/aarkam.kdouja:v1.0.3 verify --deep --json

# 2. Create SHA-256 verified backup archive
docker run --rm -e KDOUJA_TOKEN \
  -v /mnt/nvme/aarkam/kdouja:/var/lib/kdouja \
  -v /mnt/backups:/backups \
  aarkam/aarkam.kdouja:v1.0.3 backup --dest /backups/kdouja-$(date +%F).zip --json
```

### Recipe C: License Activation & Fingerprint Extraction (No Auth Required)
```bash
docker run --rm aarkam/aarkam.kdouja:v1.0.3 license fingerprint --json
docker run --rm \
  -v /mnt/nvme/aarkam/kdouja:/var/lib/kdouja \
  -v /opt/licenses:/licenses:ro \
  aarkam/aarkam.kdouja:v1.0.3 license apply --bundle /licenses/kdouja.arklic --dir /var/lib/kdouja
```
