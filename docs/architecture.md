---
layout: default
title: Architecture
nav_order: 3
---

# Architecture

## Components

- `caked`: core background daemon
- `cakectl`: command-line controller
- `cakedlib`: shared library code
- `grpc`: communication contracts and streaming/client interfaces
- **LXD REST API** (`Sources/caked/REST/`): optional LXD-compatible HTTP/HTTPS server built into `caked`
- **Web UI** (`webui/`): React/Vite frontend served by `caked` at `/ui`

## High-level flow

1. `cakectl` sends commands to `caked` over gRPC
2. `caked` executes lifecycle/resource operations
3. Responses and streams are transmitted through gRPC back to clients
4. Logs/status are returned to clients

Optionally, external LXD-compatible tooling communicates with `caked` through the REST API:

1. `caked` starts an HTTP(S) listener alongside the gRPC server when `--rest` is set
2. LXD REST clients (e.g. `lxc`, the web UI, or any HTTP client) call `/1.0/...` endpoints
3. `caked` translates REST requests into the same internal operations used by gRPC

## Service responsibilities

`caked` is responsible for:
- lifecycle management (build, launch, start/stop/restart/suspend/delete)
- resource allocation
- health monitoring
- logging and diagnostics
- optional LXD-compatible REST API (instances, networks, images, certificates, identities, operations)
- optional Web UI hosting

## LXD REST API

When started with `--rest`, `caked` exposes an LXD-compatible REST API:

| Endpoint group | Description |
| --- | --- |
| `/1.0` | Server info and capabilities |
| `/1.0/instances` | VM lifecycle, state, exec, console, logs |
| `/1.0/networks` | Network management |
| `/1.0/images` | Image listing and metadata |
| `/1.0/operations` | Async operation tracking |
| `/1.0/certificates` | TLS certificate management |
| `/1.0/auth-groups` | Authorization groups |
| `/1.0/identities` | Identity management |

Default ports: `8443` (HTTPS/mTLS) or `8080` (HTTP). Override with `--rest-port`.

See [Command Summary](command-summary) for full `service listen` flag reference.

## Repository Structure

```text
Sources/
├── caked/          # Daemon implementation
│   └── REST/       # LXD REST API server and controllers
├── caker/          # GUI app (macOS SwiftUI)
├── cakectl/        # CLI client
├── cakedlib/       # Shared libraries
└── grpc/           # gRPC definitions and generated code
webui/              # React/Vite web UI
```
