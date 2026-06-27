---
layout: default
title: Cheat Sheet
nav_order: 9
---

# Cheat Sheet

Quick command reference for common daily operations.

> ⚠️ If the `caked` service is active, do not use `caked` directly. Use `cakectl` commands against the running service.

## VM lifecycle (`cakectl`)

- List VMs:
  - `cakectl list`
- Get VM details:
  - `cakectl infos <vm-name>`
- Start / stop / restart:
  - `cakectl start <vm-name>`
  - `cakectl stop <vm-name>`
  - `cakectl restart <vm-name>`
- Launch a new VM:
  - `cakectl launch ...`

## Authentication for webui (`cakectl certificate`)

- List registered certificates:
  - `cakectl certificate list`
- Add a certificate (from file or stdin):
  - `cakectl certificate add --name <name> <cert.pem>`
  - `cat cert.pem | cakectl certificate add --name <name>`
- Get a certificate (outputs PEM):
  - `cakectl certificate get <fingerprint-or-name>`
- Remove a certificate:
  - `cakectl certificate delete <fingerprint-or-name>`

## Guest access (`cakectl`)

- Run one command in guest:
  - `cakectl exec <vm-name> -- <command> [args...]`
- Open guest shell:
  - `cakectl sh <vm-name>`
- Wait for IP:
  - `cakectl waitip <vm-name>`
- Open VNC display:
  - `cakectl vnc <vm-name>`

## Images and registry (`cakectl`)

- Image list/info/pull:
  - `cakectl image list <remote>`
  - `cakectl image info <image>`
  - `cakectl image pull <image>`
- Registry auth:
  - `cakectl login <host>`
  - `cakectl logout <host>`
- Push/pull VM images:
  - `cakectl pull <name> <image>`
  - `cakectl push <local-name> <remote-name>`

## Networks (`cakectl`)

- List networks:
  - `cakectl networks list`
- Inspect one network:
  - `cakectl networks infos <network>`
- Create/start/stop:
  - `cakectl networks create ...`
  - `cakectl networks start <network>`
  - `cakectl networks stop <network>`

## Compose (`cakectl compose`)

- Initialise a project:
  - `cakectl compose init`
- Start all services:
  - `cakectl compose up`
- Start specific services:
  - `cakectl compose up app database`
- Stop all services:
  - `cakectl compose down`
- Show service status:
  - `cakectl compose ps`
- Remove and unregister (stop first):
  - `cakectl compose rm --stop`
- List all compose projects:
  - `cakectl compose ls`
- Use a custom file:
  - `cakectl compose up -f ./infra/staging.yml`

## Local daemon/admin (`caked`)

- Run daemon command directly:
  - `caked <command> ...`
- Certificates:
  - `caked certificates get`
  - `caked certificates generate`
- Service mode:
  - `caked service listen --secure` *(enable secure traffic)*
  - `caked service listen --tcp --secure`  *(enable listen on tcp)*
  - `caked service listen --rest` *(enable LXD REST API)*
  - `caked service listen --rest --web-ui /path/to/webui/dist` *(with web UI)*
  - `caked service status`
  - `caked service stop`
- Convert disk images:
  - `caked convert source.qcow2 destination.raw`
  - `caked convert --source-format vmdk source.vmdk destination.raw`

## Useful global options

- `cakectl --connect <address>`
- `cakectl --disable-tls`
- `cakectl --system`
- `caked --log-level <level>`
- `caked --format json`

## Docs links

- Detailed command groups: [Command Summary](command-summary)
- Troubleshooting: [Troubleshooting](troubleshooting)

## Real workflows

### 1) Create and start a VM

from OCI registry

```bash
cakectl build --name demo-vm --cpu 4 --memory 8192 --disk-size 40G oci://ghcr.io/example/image:latest
```

from https

```bash
cakectl build --name demo-vm --cpu 4 --memory 8192 --disk-size 40G https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-arm64.img
```

from simplestream remote

```bash
cakectl build --name demo-vm --cpu 4 --memory 8192 --disk-size 40G ubuntu:noble
```

### 2) Start an existing VM, wait for IP, inspect status

```bash
cakectl start demo-vm
cakectl waitip demo-vm
cakectl infos demo-vm
```

### 3) Open shell and run one command in guest

```bash
cakectl shell demo-vm
cakectl exec demo-vm -- uname -a
```

### 6) Connect to VM display via VNC

```bash
cakectl start demo-vm
cakectl vnc demo-vm
```

### 7) Convert a QCOW2 or VMDK image to raw

```bash
# QCOW2 (default)
caked convert ubuntu-cloud.qcow2 ubuntu.raw

# VMDK
caked convert --source-format vmdk disk.vmdk disk.raw
```

### 4) Push a local VM image to remote registry

```bash
cakectl login ghcr.io --username <username> --password <password>
cakectl push demo-vm ghcr.io/<owner>/demo-vm:latest
cakectl logout ghcr.io
```

### 5) Create and manage a shared network

```bash
cakectl networks create --name shared-dev --mode shared --gateway 192.168.105.1 --dhcp-end 192.168.105.254 --netmask 255.255.255.0
cakectl networks start shared-dev
cakectl networks infos shared-dev
cakectl networks stop shared-dev
```
