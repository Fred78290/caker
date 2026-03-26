---
layout: page
title: Cheat Sheet
nav_order: 9
---

# Cheat Sheet

Quick command reference for common daily operations.

{: .note }
If the `caked` service is active, do not use `caked` directly. Use `cakectl` commands against the running service.

## VM Lifecycle (`cakectl`)

**List VMs:**
```bash
cakectl list
```

**Get VM details:**
```bash
cakectl infos <vm-name>
```

**Start / stop / restart:**
```bash
cakectl start <vm-name>
cakectl stop <vm-name>
cakectl restart <vm-name>
```

**Launch a new VM:**
```bash
cakectl launch ...
```

## Guest Access (`cakectl`)

**Run one command in guest:**
```bash
cakectl exec <vm-name> -- <command> [args...]
```

**Open guest shell:**
```bash
cakectl sh <vm-name>
```

**Wait for IP:**
```bash
cakectl waitip <vm-name>
```

## Images and Registry (`cakectl`)

**Image operations:**
```bash
cakectl image list <remote>
cakectl image info <image>
cakectl image pull <image>
```

**Registry authentication:**
```bash
cakectl login <host>
cakectl logout <host>
```

**Push/pull VM images:**
```bash
cakectl pull <name> <image>
cakectl push <local-name> <remote-name>
```

## Networks (`cakectl`)

**List networks:**
```bash
cakectl networks list
```

**Inspect network:**
```bash
cakectl networks infos <network>
```

**Create/start/stop:**
```bash
cakectl networks create ...
cakectl networks start <network>
cakectl networks stop <network>
```

## Local Daemon/Admin (`caked`)

**Run daemon command directly:**
```bash
caked <command> ...
```

**Certificates:**
```bash
caked certificates get
caked certificates generate
```

**Service mode:**
```bash
caked service ...
```

## Useful Global Options

- `cakectl --connect <address>`
- `cakectl --disable-tls`
- `cakectl --system`
- `caked --log-level <level>`
- `caked --format json`

## Quick Links

- Detailed command groups: [Command Summary](command-summary)
- Troubleshooting: [Troubleshooting](troubleshooting)

## Real Workflows

### 1) Create and Start a VM

**From OCI registry:**
```bash
cakectl build --name demo-vm --cpu 4 --memory 8192 --disk-size 40G \
  oci://ghcr.io/example/image:latest
```

**From HTTPS:**
```bash
cakectl build --name demo-vm --cpu 4 --memory 8192 --disk-size 40G \
  https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-arm64.img
```

**From simplestream remote:**
```bash
cakectl build --name demo-vm --cpu 4 --memory 8192 --disk-size 40G ubuntu:noble
```

### 2) Start VM, Wait for IP, Inspect Status

```bash
cakectl start demo-vm
cakectl waitip demo-vm
cakectl infos demo-vm
```

### 3) Open Shell and Run Commands

```bash
cakectl shell demo-vm
cakectl exec demo-vm -- uname -a
```

### 4) Push Local VM Image to Remote Registry

```bash
cakectl login ghcr.io --username <username> --password <password>
cakectl push demo-vm ghcr.io/<owner>/demo-vm:latest
cakectl logout ghcr.io
```

### 5) Create and Manage Shared Network

```bash
cakectl networks create --name shared-dev --mode shared \
  --gateway 192.168.105.1 --dhcp-end 192.168.105.254 --netmask 255.255.255.0
cakectl networks start shared-dev
cakectl networks infos shared-dev
cakectl networks stop shared-dev
```