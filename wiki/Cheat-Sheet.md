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

## Guest access (`cakectl`)

- Run one command in guest:
  - `cakectl exec <vm-name> -- <command> [args...]`
- Open guest shell:
  - `cakectl sh <vm-name>`
- Wait for IP:
  - `cakectl waitip <vm-name>`

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

## Local daemon/admin (`caked`)

- Run daemon command directly:
  - `caked <command> ...`
- Certificates:
  - `caked certificates get`
  - `caked certificates generate`
- Service mode:
  - `caked service ...`

## Useful global options

- `cakectl --connect <address>`
- `cakectl --disable-tls`
- `cakectl --system`
- `caked --log-level <level>`
- `caked --format json`

## Docs links

- Detailed command groups: [Command Summary](Command-Summary)
- Troubleshooting: [Troubleshooting](Troubleshooting)

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
