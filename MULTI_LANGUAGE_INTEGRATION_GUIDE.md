# Aarkam Kdouja — Multi-Language gRPC & HTTP Integration Guide

> **Protocol:** gRPC over HTTP/2 (`proto3`) + HTTP/1.1 Management & Health API  
> **Canonical Schema:** [`protos/kdouja.proto`](./protos/kdouja.proto) (`package aarkam.kdouja`)  
> **Default Endpoint:** `http://localhost:57771` (or `https://<host>:57771` with TLS/mTLS)  
> **Max Message Size:** `32 MB` (Send & Receive)  
> **gRPC Server Reflection:** Enabled out-of-the-box (`grpc.reflection.v1alpha.ServerReflection`)

Because **Aarkam Kdouja (`kdoujad`)** exposes a standard **Protocol Buffers (`proto3`) gRPC** interface alongside a lightweight JSON HTTP API, **any backend language** — Go, Java, Kotlin, Python, Node.js/TypeScript, Rust, C++, C, PHP, Ruby, Swift, or .NET — can connect directly with zero proprietary runtime dependencies.

---

## Table of Contents

1. [Protocol Architecture & Connection Prerequisites](#1-protocol-architecture--connection-prerequisites)
2. [Canonical `kdouja.proto` Contract Reference](#2-canonical-kdoujaproto-contract-reference)
3. [Zero-Trust Auth Headers & License Error Trailers](#3-zero-trust-auth-headers--license-error-trailers)
4. [Quick Schema Discovery with `grpcurl`](#4-quick-schema-discovery-with-grpcurl)
5. [Go Integration (`google.golang.org/grpc`)](#5-go-integration-googlegolangorggrpc)
6. [Java / Kotlin Integration (`grpc-java`)](#6-java--kotlin-integration-grpc-java)
7. [Python Integration (`grpcio`)](#7-python-integration-grpcio)
8. [Node.js / TypeScript Integration (`@grpc/grpc-js`)](#8-nodejs--typescript-integration-grpcgrpc-js)
9. [Rust Integration (`tonic` + `prost`)](#9-rust-integration-tonic--prost)
10. [C++ Integration (`gRPC C++` + CMake)](#10-c-integration-grpc-c--cmake)
11. [C Integration (Pure C via `libcurl` HTTP API or C++ `extern "C"` Bridge)](#11-c-integration-pure-c-via-libcurl-http-api-or-c-extern-c-bridge)
12. [PHP Integration (`grpc/grpc`)](#12-php-integration-grpcgrpc)
13. [C# / .NET Official SDK (`Aarkam.Kdouja.SDK`)](#13-c--net-official-sdk-aarkamkdoujasdk)
14. [Production Performance & Tuning Checklist](#14-production-performance--tuning-checklist)

---

## 1. Protocol Architecture & Connection Prerequisites

### Transport & HTTP/2 Configuration (Critical)
`kdoujad` runs on ASP.NET Core Kestrel listening on port **`57771`**.

- **With TLS / mTLS (`https://host:57771` — Recommended for Production):**
  Kestrel negotiates HTTP/2 automatically over ALPN (`Protocols: Http1AndHttp2`). Both gRPC and HTTP/1.1 (`/healthz`) work on the same port.
- **Cleartext HTTP/2 (`http://host:57771` — Local / Private Air-Gapped Network):**
  Kestrel requires `Protocols: Http2` on cleartext `http://` endpoints for h2c (unencrypted HTTP/2) gRPC clients:
  ```json
  {
    "Kestrel": {
      "EndpointDefaults": {
        "Protocols": "Http2"
      }
    }
  }
  ```
  *(Or expose two separate Kestrel endpoints: port `57771` with `Http2` for gRPC and port `8080` with `Http1` for `/healthz` and `/api/v1/*`.)*

### Verify Daemon Reachability First
```bash
curl -s http://localhost:57771/healthz
# Expected: Healthy

curl -s http://localhost:57771/
# Expected JSON with version, baseDirectory, status, and license summary
```

---

## 2. Canonical `kdouja.proto` Contract Reference

Download or copy [`protos/kdouja.proto`](./protos/kdouja.proto) into your project. It defines two gRPC services in `package aarkam.kdouja`:

### Service 1: `aarkam.kdouja.KeyValueService`

| RPC Method | Type | Request | Response | Description |
| :--- | :--- | :--- | :--- | :--- |
| `Put` | Unary | `PutRequest { bytes key; bytes value; bool sync; }` | `PutResponse { bool success; int64 sequence_number; }` | Insert or update a key-value record; `sync=true` forces WAL `fsync` |
| `Get` | Unary | `GetRequest { bytes key; }` | `GetResponse { bool found; bytes value; }` | Sub-millisecond point lookup |
| `Delete` | Unary | `DeleteRequest { bytes key; bool sync; }` | `DeleteResponse { bool success; int64 sequence_number; }` | Write a deletion tombstone |
| `WriteBatch` | Unary | `BatchWriteRequest { repeated MutationEntry mutations; bool sync; }` | `BatchWriteResponse { bool success; int32 applied_count; }` | Atomic multi-key `PUT` / `DELETE` batch (`OperationType`: `PUT=0`, `DELETE=1`) |
| `Scan` | **Server Streaming** | `ScanRequest { bytes start_key; bytes end_key; int32 limit; }` | `stream KeyValueRecord { bytes key; bytes value; }` | Lexicographically ordered range scan (empty `start_key`/`end_key` = unbounded, `limit=0` = unlimited) |
| `GetMetrics` | Unary | `MetricsRequest {}` | `MetricsResponse` | Live sequence number, active SSTables, MemTable bytes, WAF/RAF, Bloom hit rate |

### Service 2: `aarkam.kdouja.StorageService` (Direct-I/O `.aarkam` PageStore Chunk Streaming)

| RPC Method | Type | Request | Response | Description |
| :--- | :--- | :--- | :--- | :--- |
| `StoreChunk` | **Client Streaming** | `stream ChunkWriteRequest { string file_id; int32 chunk_index; bytes ciphertext; bytes iv; bytes tag; }` | `ChunkWriteResponse { bool success; string message; int64 page_id; }` | Streams encrypted chunks directly into 256 MB `.aarkam` Direct-I/O PageStore segments |
| `RetrieveChunk` | **Server Streaming** | `ChunkReadRequest { string file_id; int32 chunk_index; }` | `stream ChunkReadResponse { bytes ciphertext; bytes iv; bytes tag; }` | Streams stored encrypted chunks back from PageStore |

### Companion HTTP/1.1 Management & KV API (Port `57771`)
For environments or languages without gRPC/HTTP2 (such as pure C, shell scripts, or lightweight health probes):

| Method & Path | Payload / Query | Response |
| :--- | :--- | :--- |
| `GET /healthz` | — | `200 OK` (`Healthy`) |
| `GET /` | — | Daemon version, `baseDirectory`, `status`, and `license` JSON |
| `GET /api/v1/metrics` | — | Full `KeyValueEngine` runtime metrics JSON |
| `POST /api/v1/kv/put` | `{"keyBase64":"...","valueBase64":"...","sync":true}` | `{"success":true,"sequenceNumber":42}` |
| `GET /api/v1/kv/get?key=<base64>` | URL-encoded Base64 key | `{"found":true,"valueBase64":"..."}` |
| `POST /api/v1/kv/delete` | `{"keyBase64":"...","sync":true}` | `{"success":true,"sequenceNumber":43}` |
| `GET /api/v1/kv/scan?start=<b64>&end=<b64>&limit=100` | Optional Base64 bounds | `[{"keyBase64":"...","valueBase64":"..."}]` |
| `POST /api/v1/compact` | — | `{"databasePath":"...","sstablesBefore":4,"sstablesAfter":1,"elapsedMilliseconds":120}` |

---

## 3. Zero-Trust Auth Headers & License Error Trailers

### Optional Zero-Trust gRPC Metadata Headers
When connecting through Aarkam Rokka, Abodi, or an auth-protected `kdoujad` gateway, attach lowercase gRPC metadata headers:

| Header | Example | Usage |
| :--- | :--- | :--- |
| `x-api-key` | `ak_live_...` | Application / service API key |
| `x-rokka-node-key` | `rk_node_...` | Cluster node-to-node key |
| `authorization` | `Bearer <jwt_or_session_token>` | Operator or service-account bearer token |

### Handling License-Locked Errors (`PERMISSION_DENIED`)
If the node's 30-day evaluation or subscription license expires, reads remain available for sovereign data recovery, while write RPCs (`Put`, `Delete`, `WriteBatch`, `StoreChunk`) return gRPC status **`PERMISSION_DENIED` (code `7`)** with structured trailers:
- `x-kdouja-license-status` (e.g. `Expired`, `Invalid`)
- `x-kdouja-suggested-action` (remediation command)
- `x-kdouja-node-fingerprint` (e.g. `ARK-FP-AD8FF9EE-77AEB122-F222165B`)

---

## 4. Quick Schema Discovery with `grpcurl`

Because `kdoujad` enables gRPC Server Reflection, you can inspect and test RPCs immediately without even downloading `.proto` files:

```bash
# List exposed services
grpcurl -plaintext localhost:57771 list

# Describe KeyValueService methods
grpcurl -plaintext localhost:57771 describe aarkam.kdouja.KeyValueService

# Put key "hello" (aGVsbG8=) = "world" (d29ybGQ=)
grpcurl -plaintext -d '{"key":"aGVsbG8=","value":"d29ybGQ=","sync":true}' \
  localhost:57771 aarkam.kdouja.KeyValueService/Put

# Get key "hello"
grpcurl -plaintext -d '{"key":"aGVsbG8="}' \
  localhost:57771 aarkam.kdouja.KeyValueService/Get

# Fetch live engine metrics
grpcurl -plaintext -d '{}' \
  localhost:57771 aarkam.kdouja.KeyValueService/GetMetrics
```

---

## 5. Go Integration (`google.golang.org/grpc`)

### Step 1: Install Protobuf & gRPC Plugins
```bash
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
```

### Step 2: Generate Go Stubs
```bash
mkdir -p gen/kdoujapb
protoc -I ./protos \
  --go_out=gen/kdoujapb --go_opt=paths=source_relative,Mkdouja.proto=example.com/app/gen/kdoujapb \
  --go-grpc_out=gen/kdoujapb --go-grpc_opt=paths=source_relative,Mkdouja.proto=example.com/app/gen/kdoujapb \
  ./protos/kdouja.proto
```

### Step 3: Go Client Example (`main.go`)
```go
package main

import (
	"context"
	"fmt"
	"io"
	"log"
	"time"

	pb "example.com/app/gen/kdoujapb"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/metadata"
)

func main() {
	// Reuse a single ClientConn across your entire service (thread-safe, multiplexed HTTP/2)
	conn, err := grpc.NewClient(
		"localhost:57771",
		grpc.WithTransportCredentials(insecure.NewCredentials()), // Use credentials.NewTLS(...) in production
		grpc.WithDefaultCallOptions(
			grpc.MaxCallRecvMsgSize(32*1024*1024),
			grpc.MaxCallSendMsgSize(32*1024*1024),
		),
	)
	if err != nil {
		log.Fatalf("dial kdouja: %v", err)
	}
	defer conn.Close()

	client := pb.NewKeyValueServiceClient(conn)

	// Attach optional Zero-Trust auth metadata + deadline
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	ctx = metadata.AppendToOutgoingContext(ctx, "x-api-key", "your-api-key")

	// 1. Put
	putResp, err := client.Put(ctx, &pb.PutRequest{
		Key:   []byte("order:1001"),
		Value: []byte(`{"total":249.50,"currency":"SAR"}`),
		Sync:  true,
	})
	if err != nil {
		log.Fatalf("Put failed: %v", err)
	}
	fmt.Printf("PUT ok (seq=%d)\n", putResp.SequenceNumber)

	// 2. Get
	getResp, err := client.Get(ctx, &pb.GetRequest{Key: []byte("order:1001")})
	if err != nil {
		log.Fatalf("Get failed: %v", err)
	}
	if getResp.Found {
		fmt.Printf("GET order:1001 => %s\n", string(getResp.Value))
	}

	// 3. Atomic WriteBatch
	batchResp, err := client.WriteBatch(ctx, &pb.BatchWriteRequest{
		Sync: true,
		Mutations: []*pb.MutationEntry{
			{Type: pb.OperationType_PUT, Key: []byte("order:1002"), Value: []byte("paid")},
			{Type: pb.OperationType_DELETE, Key: []byte("order:legacy")},
		},
	})
	if err != nil {
		log.Fatalf("WriteBatch failed: %v", err)
	}
	fmt.Printf("Batch applied: %d\n", batchResp.AppliedCount)

	// 4. Server-Streaming Range Scan
	stream, err := client.Scan(ctx, &pb.ScanRequest{
		StartKey: []byte("order:"),
		EndKey:   []byte("order:~"),
		Limit:    100,
	})
	if err != nil {
		log.Fatalf("Scan failed: %v", err)
	}
	for {
		rec, err := stream.Recv()
		if err == io.EOF {
			break
		}
		if err != nil {
			log.Fatalf("Scan recv: %v", err)
		}
		fmt.Printf("  %s => %s\n", string(rec.Key), string(rec.Value))
	}

	// 5. Live Metrics
	metrics, err := client.GetMetrics(ctx, &pb.MetricsRequest{})
	if err != nil {
		log.Fatalf("GetMetrics failed: %v", err)
	}
	fmt.Printf("Metrics: seq=%d sstables=%d bloomHit=%.2f%%\n",
		metrics.SequenceNumber, metrics.ActiveSstables, metrics.BloomFilterHitRate*100)
}
```

---

## 6. Java / Kotlin Integration (`grpc-java`)

### Step 1: Maven Dependencies & Codegen (`pom.xml`)
Place `kdouja.proto` in `src/main/proto/kdouja.proto`:

```xml
<properties>
  <grpc.version>1.68.1</grpc.version>
  <protobuf.version>4.28.2</protobuf.version>
</properties>

<dependencies>
  <dependency>
    <groupId>io.grpc</groupId>
    <artifactId>grpc-netty-shaded</artifactId>
    <version>${grpc.version}</version>
  </dependency>
  <dependency>
    <groupId>io.grpc</groupId>
    <artifactId>grpc-protobuf</artifactId>
    <version>${grpc.version}</version>
  </dependency>
  <dependency>
    <groupId>io.grpc</groupId>
    <artifactId>grpc-stub</artifactId>
    <version>${grpc.version}</version>
  </dependency>
</dependencies>

<build>
  <extensions>
    <extension>
      <groupId>kr.motd.maven</groupId>
      <artifactId>os-maven-plugin</artifactId>
      <version>1.7.1</version>
    </extension>
  </extensions>
  <plugins>
    <plugin>
      <groupId>org.xolstice.maven.plugins</groupId>
      <artifactId>protobuf-maven-plugin</artifactId>
      <version>0.6.1</version>
      <configuration>
        <protocArtifact>com.google.protobuf:protoc:${protobuf.version}:exe:${os.detected.classifier}</protocArtifact>
        <pluginId>grpc-java</pluginId>
        <pluginArtifact>io.grpc:protoc-gen-grpc-java:${grpc.version}:exe:${os.detected.classifier}</pluginArtifact>
      </configuration>
      <executions>
        <execution>
          <goals>
            <goal>compile</goal>
            <goal>compile-custom</goal>
          </goals>
        </execution>
      </executions>
    </plugin>
  </plugins>
</build>
```

### Step 2: Java Client Example (`KdoujaExample.java`)
```java
import aarkam.kdouja.KeyValueServiceGrpc;
import aarkam.kdouja.Kdouja.*;
import com.google.protobuf.ByteString;
import io.grpc.ManagedChannel;
import io.grpc.ManagedChannelBuilder;
import io.grpc.Metadata;
import io.grpc.stub.MetadataUtils;

import java.nio.charset.StandardCharsets;
import java.util.Iterator;
import java.util.concurrent.TimeUnit;

public class KdoujaExample {
    public static void main(String[] args) throws InterruptedException {
        ManagedChannel channel = ManagedChannelBuilder
            .forAddress("localhost", 57771)
            .usePlaintext() // Remove and use TLS in production
            .maxInboundMessageSize(32 * 1024 * 1024)
            .build();

        try {
            Metadata headers = new Metadata();
            headers.put(Metadata.Key.of("x-api-key", Metadata.ASCII_STRING_MARSHALLER), "your-api-key");

            KeyValueServiceGrpc.KeyValueServiceBlockingStub stub = KeyValueServiceGrpc
                .newBlockingStub(channel)
                .withInterceptors(MetadataUtils.newAttachHeadersInterceptor(headers))
                .withDeadlineAfter(10, TimeUnit.SECONDS);

            // 1. Put
            PutResponse putResp = stub.put(PutRequest.newBuilder()
                .setKey(ByteString.copyFrom("account:42", StandardCharsets.UTF_8))
                .setValue(ByteString.copyFrom("{\"status\":\"active\"}", StandardCharsets.UTF_8))
                .setSync(true)
                .build());
            System.out.println("PUT seq = " + putResp.getSequenceNumber());

            // 2. Get
            GetResponse getResp = stub.get(GetRequest.newBuilder()
                .setKey(ByteString.copyFrom("account:42", StandardCharsets.UTF_8))
                .build());
            if (getResp.getFound()) {
                System.out.println("GET value = " + getResp.getValue().toStringUtf8());
            }

            // 3. Range Scan (Server Streaming)
            Iterator<KeyValueRecord> it = stub.scan(ScanRequest.newBuilder()
                .setStartKey(ByteString.copyFrom("account:", StandardCharsets.UTF_8))
                .setEndKey(ByteString.copyFrom("account:~", StandardCharsets.UTF_8))
                .setLimit(50)
                .build());
            while (it.hasNext()) {
                KeyValueRecord rec = it.next();
                System.out.printf("  %s => %s%n", rec.getKey().toStringUtf8(), rec.getValue().toStringUtf8());
            }
        } finally {
            channel.shutdown().awaitTermination(5, TimeUnit.SECONDS);
        }
    }
}
```

---

## 7. Python Integration (`grpcio`)

### Step 1: Install & Generate Stubs
```bash
pip install grpcio grpcio-tools
python -m grpc_tools.protoc -I ./protos --python_out=. --grpc_python_out=. ./protos/kdouja.proto
```

### Step 2: Python Client Example (`kdouja_client.py`)
```python
import grpc
import kdouja_pb2
import kdouja_pb2_grpc

def main():
    options = [
        ("grpc.max_send_message_length", 32 * 1024 * 1024),
        ("grpc.max_receive_message_length", 32 * 1024 * 1024),
    ]
    metadata = [("x-api-key", "your-api-key")]

    with grpc.insecure_channel("localhost:57771", options=options) as channel:
        kv = kdouja_pb2_grpc.KeyValueServiceStub(channel)

        # 1. Put
        put_resp = kv.Put(
            kdouja_pb2.PutRequest(key=b"ml:model:v1", value=b'{"acc":0.994}', sync=True),
            metadata=metadata,
            timeout=10.0,
        )
        print(f"PUT ok (seq={put_resp.sequence_number})")

        # 2. Get
        get_resp = kv.Get(kdouja_pb2.GetRequest(key=b"ml:model:v1"), metadata=metadata)
        if get_resp.found:
            print("GET:", get_resp.value.decode("utf-8"))

        # 3. Atomic WriteBatch
        batch_resp = kv.WriteBatch(
            kdouja_pb2.BatchWriteRequest(
                sync=True,
                mutations=[
                    kdouja_pb2.MutationEntry(type=kdouja_pb2.PUT, key=b"k1", value=b"v1"),
                    kdouja_pb2.MutationEntry(type=kdouja_pb2.PUT, key=b"k2", value=b"v2"),
                ],
            ),
            metadata=metadata,
        )
        print("Batch applied:", batch_resp.applied_count)

        # 4. Streaming Scan
        for rec in kv.Scan(
            kdouja_pb2.ScanRequest(start_key=b"ml:", end_key=b"ml:~", limit=100),
            metadata=metadata,
        ):
            print(f"  {rec.key.decode()} => {rec.value.decode()}")

if __name__ == "__main__":
    main()
```

---

## 8. Node.js / TypeScript Integration (`@grpc/grpc-js`)

### Step 1: Install Packages
```bash
npm install @grpc/grpc-js @grpc/proto-loader
```

### Step 2: TypeScript / Node.js Example (`kdouja.ts`)
```typescript
import * as grpc from "@grpc/grpc-js";
import * as protoLoader from "@grpc/proto-loader";

const packageDef = protoLoader.loadSync("./protos/kdouja.proto", {
  keepCase: true,
  longs: String,
  enums: String,
  defaults: true,
  oneofs: true,
});
const proto = grpc.loadPackageDefinition(packageDef) as any;

const client = new proto.aarkam.kdouja.KeyValueService(
  "localhost:57771",
  grpc.credentials.createInsecure(),
  {
    "grpc.max_receive_message_length": 32 * 1024 * 1024,
    "grpc.max_send_message_length": 32 * 1024 * 1024,
  }
);

const meta = new grpc.Metadata();
meta.add("x-api-key", "your-api-key");

// 1. Put
client.Put(
  { key: Buffer.from("session:abc"), value: Buffer.from("active"), sync: true },
  meta,
  (err: any, resp: any) => {
    if (err) throw err;
    console.log("PUT seq:", resp.sequence_number);

    // 2. Get
    client.Get({ key: Buffer.from("session:abc") }, meta, (err2: any, getResp: any) => {
      if (err2) throw err2;
      if (getResp.found) {
        console.log("GET value:", Buffer.from(getResp.value).toString("utf8"));
      }
    });

    // 3. Server-Streaming Scan
    const stream = client.Scan(
      { start_key: Buffer.from("session:"), end_key: Buffer.from("session:~"), limit: 50 },
      meta
    );
    stream.on("data", (rec: any) => {
      console.log(`  ${Buffer.from(rec.key).toString()} => ${Buffer.from(rec.value).toString()}`);
    });
    stream.on("end", () => console.log("Scan complete"));
  }
);
```

---

## 9. Rust Integration (`tonic` + `prost`)

### Step 1: `Cargo.toml` & `build.rs`
```toml
[dependencies]
tonic = "0.12"
prost = "0.13"
tokio = { version = "1", features = ["macros", "rt-multi-thread"] }

[build-dependencies]
tonic-build = "0.12"
```

```rust
// build.rs
fn main() -> Result<(), Box<dyn std::error::Error>> {
    tonic_build::compile_protos("protos/kdouja.proto")?;
    Ok(())
}
```

### Step 2: Rust Async Client (`src/main.rs`)
```rust
pub mod kdouja {
    tonic::include_proto!("aarkam.kdouja");
}

use kdouja::key_value_service_client::KeyValueServiceClient;
use kdouja::{GetRequest, PutRequest, ScanRequest};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut client = KeyValueServiceClient::connect("http://127.0.0.1:57771")
        .await?
        .max_decoding_message_size(32 * 1024 * 1024)
        .max_encoding_message_size(32 * 1024 * 1024);

    // 1. Put
    let put_resp = client
        .put(PutRequest {
            key: b"rust:node1".to_vec(),
            value: b"online".to_vec(),
            sync: true,
        })
        .await?
        .into_inner();
    println!("PUT seq = {}", put_resp.sequence_number);

    // 2. Get
    let get_resp = client
        .get(GetRequest { key: b"rust:node1".to_vec() })
        .await?
        .into_inner();
    if get_resp.found {
        println!("GET = {}", String::from_utf8_lossy(&get_resp.value));
    }

    // 3. Streaming Scan
    let mut stream = client
        .scan(ScanRequest {
            start_key: b"rust:".to_vec(),
            end_key: b"rust:~".to_vec(),
            limit: 100,
        })
        .await?
        .into_inner();

    while let Some(rec) = stream.message().await? {
        println!(
            "  {} => {}",
            String::from_utf8_lossy(&rec.key),
            String::from_utf8_lossy(&rec.value)
        );
    }
    Ok(())
}
```

---

## 10. C++ Integration (`gRPC C++` + CMake)

### Step 1: Generate C++ Sources
```bash
protoc -I ./protos \
  --cpp_out=./gen \
  --grpc_out=./gen \
  --plugin=protoc-gen-grpc=$(which grpc_cpp_plugin) \
  ./protos/kdouja.proto
```

### Step 2: C++ Client Example (`main.cpp`)
```cpp
#include <iostream>
#include <memory>
#include <string>
#include <grpcpp/grpcpp.h>
#include "kdouja.grpc.pb.h"

using grpc::Channel;
using grpc::ClientContext;
using grpc::Status;
using aarkam::kdouja::KeyValueService;
using aarkam::kdouja::PutRequest;
using aarkam::kdouja::PutResponse;
using aarkam::kdouja::GetRequest;
using aarkam::kdouja::GetResponse;
using aarkam::kdouja::ScanRequest;
using aarkam::kdouja::KeyValueRecord;

int main() {
    grpc::ChannelArguments args;
    args.SetMaxReceiveMessageSize(32 * 1024 * 1024);
    args.SetMaxSendMessageSize(32 * 1024 * 1024);

    auto channel = grpc::CreateCustomChannel(
        "localhost:57771",
        grpc::InsecureChannelCredentials(), // Use SslCredentials in production
        args);
    auto stub = KeyValueService::NewStub(channel);

    // 1. Put
    {
        ClientContext ctx;
        ctx.AddMetadata("x-api-key", "your-api-key");
        PutRequest req;
        req.set_key("cpp:sensor:01");
        req.set_value("24.8C");
        req.set_sync(true);

        PutResponse resp;
        Status st = stub->Put(&ctx, req, &resp);
        if (!st.ok()) {
            std::cerr << "Put failed: " << st.error_message() << std::endl;
            return 1;
        }
        std::cout << "PUT seq = " << resp.sequence_number() << std::endl;
    }

    // 2. Get
    {
        ClientContext ctx;
        GetRequest req;
        req.set_key("cpp:sensor:01");
        GetResponse resp;
        if (stub->Get(&ctx, req, &resp).ok() && resp.found()) {
            std::cout << "GET value = " << resp.value() << std::endl;
        }
    }

    // 3. Streaming Scan
    {
        ClientContext ctx;
        ScanRequest req;
        req.set_start_key("cpp:");
        req.set_end_key("cpp:~");
        req.set_limit(100);

        auto reader = stub->Scan(&ctx, req);
        KeyValueRecord rec;
        while (reader->Read(&rec)) {
            std::cout << "  " << rec.key() << " => " << rec.value() << std::endl;
        }
    }
    return 0;
}
```

---

## 11. C Integration (Pure C via `libcurl` HTTP API or C++ `extern "C"` Bridge)

Because gRPC does not ship an official pure-C code generator, C applications have two clean options:

### Option A: Pure C via `kdoujad` HTTP/1.1 JSON API (`libcurl`) — Zero C++ Toolchain
```c
#include <stdio.h>
#include <curl/curl.h>

int main(void) {
    CURL *curl = curl_easy_init();
    if (!curl) return 1;

    // Base64("c:key") = "YzprZXk=", Base64("hello") = "aGVsbG8="
    const char *json = "{\"keyBase64\":\"YzprZXk=\",\"valueBase64\":\"aGVsbG8=\",\"sync\":true}";

    struct curl_slist *headers = NULL;
    headers = curl_slist_append(headers, "Content-Type: application/json");

    curl_easy_setopt(curl, CURLOPT_URL, "http://127.0.0.1:57771/api/v1/kv/put");
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl, CURLOPT_POSTFIELDS, json);

    CURLcode res = curl_easy_perform(curl);
    if (res != CURLE_OK) {
        fprintf(stderr, "curl failed: %s\n", curl_easy_strerror(res));
    }

    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);
    return 0;
}
```
Compile: `gcc main.c -lcurl -o kdouja_c_client`

### Option B: High-Throughput Binary gRPC from C
Compile the C++ client in [Section 10](#10-c-integration-grpc-c--cmake) into a shared library (`libkdouja_ffi.so` / `kdouja_ffi.dll`) exporting `extern "C"` functions (`kdouja_connect`, `kdouja_put`, `kdouja_get`, `kdouja_close`) and link it directly from pure C.

---

## 12. PHP Integration (`grpc/grpc`)

### Step 1: Install Extension & Generate Stubs
```bash
pecl install grpc protobuf
composer require grpc/grpc google/protobuf
protoc -I ./protos --php_out=./gen --grpc_out=./gen --plugin=protoc-gen-grpc=$(which grpc_php_plugin) ./protos/kdouja.proto
```

### Step 2: PHP Client Example (`index.php`)
```php
<?php
require 'vendor/autoload.php';

$client = new \Aarkam\Kdouja\KeyValueServiceClient('localhost:57771', [
    'credentials' => \Grpc\ChannelCredentials::createInsecure(),
    'grpc.max_receive_message_length' => 32 * 1024 * 1024,
]);

$put = new \Aarkam\Kdouja\PutRequest();
$put->setKey('php:user:1');
$put->setValue('{"role":"admin"}');
$put->setSync(true);

list($resp, $status) = $client->Put($put, ['x-api-key' => ['your-api-key']])->wait();
if ($status->code === \Grpc\STATUS_OK) {
    echo "PUT seq = " . $resp->getSequenceNumber() . PHP_EOL;
}
```

---

## 13. C# / .NET Official SDK (`Aarkam.Kdouja.SDK`)

For .NET 8.0 / .NET 10.0 applications, use the official NuGet packages (`v1.0.3`):

```bash
dotnet add package Aarkam.Kdouja.SDK --version 1.0.3
dotnet add package Aarkam.Kdouja.SDK.Remote --version 1.0.3   # Standalone gRPC daemon
# or for zero-hop in-process embedded mode:
dotnet add package Aarkam.Kdouja.SDK.Embedded --version 1.0.3
```

```csharp
builder.Services.AddKdoujaRemote(opts =>
{
    opts.Endpoint = "http://localhost:57771";
    opts.Auth.ApiKey = "your-api-key";
});
```

---

## 14. Production Performance & Tuning Checklist

1. **Reuse a single gRPC channel per process:** HTTP/2 multiplexes thousands of concurrent RPCs over one TCP connection. Never create a new channel per request.
2. **Batch writes with `WriteBatch`:** When ingesting > 100 keys/sec, group 250–2,000 mutations per `WriteBatch` call to amortize WAL `fsync` and network RTT.
3. **Set `MaxReceiveMessageSize` / `MaxSendMessageSize` to `32 MB`:** Matches `kdoujad`'s server limit for large payloads and `StorageService` chunk streaming.
4. **Use `StorageService.StoreChunk` for large binary blobs (> 64 KB):** Routes payloads directly into 256 MB `.aarkam` Direct-I/O PageStore segments, keeping LSM Write Amplification low (`1.2x–3.5x`).
5. **Handle `PERMISSION_DENIED` trailers:** Inspect `x-kdouja-license-status` and `x-kdouja-node-fingerprint` on `StatusCode.PermissionDenied` so monitoring alerts operators before or upon license expiration.
6. **Enable TLS/mTLS in production:** Use `https://` with Aarkam-issued certificates and keep `Protocols: Http1AndHttp2` enabled on Kestrel.
