# Compose

Caker compose lets you define and manage multi-VM environments from a `compose.yml` file, using a format compatible with Docker Compose.

## Quick start

```bash
# Generate a template compose.yml in the current directory
cakectl compose init

# Edit compose.yml, then start all services
cakectl compose up

# Check status
cakectl compose ps

# Stop all services
cakectl compose down

# Remove all service VMs
cakectl compose rm --stop
```

## File lookup order

When `-f` is not specified, Caker looks for a compose file in the current directory in this order:

1. `compose.yml`
2. `compose.yaml`
3. `docker-compose.yml`
4. `docker-compose.yaml`

## compose.yml format

```yaml
name: myproject          # project name — also used as VM name prefix

services:
  app:
    image: ubuntu:24.04  # cloud image; same syntax as cakectl build
    ports:
      - "3000:3000"      # host:container[/proto] — TCP by default
      - "8080:80/tcp"
    sockets:             # Caker extension: unix socket forwarding
      - "/tmp/docker.sock:/var/run/docker.sock"
      - "/tmp/host.sock:/tmp/guest.sock/udp"
    volumes:
      - ".:/workspace"   # host:guest virtio-FS mount
    environment:         # injected into /etc/environment via cloud-init
      - NODE_ENV=production
      - DEBUG=1
    networks:
      - default          # named network defined in the networks: section
    depends_on:
      - database         # start database before app (list or condition map)
    deploy:
      resources:
        limits:
          cpus: "2"      # vCPU count
          memory: 2048M  # RAM: M/MB, G/GB
    hostname: app-host   # guest hostname
    restart: "no"        # accepted but informational only (VMs, not containers)

    # Caker VM extensions (not part of Docker Compose spec):
    disk: 20             # root disk size in GiB (default 10)
    user: ubuntu         # guest username for exec/sh
    password: ubuntu     # guest password
    nested: false        # enable nested virtualisation
    autostart: false     # start this VM when caked starts

  database:
    image: ubuntu:24.04
    environment:
      POSTGRES_PASSWORD: secret
    networks:
      - default
    deploy:
      resources:
        limits:
          cpus: "2"
          memory: 4096M
    disk: 40
    user: ubuntu
    password: ubuntu

networks:
  default:
    driver: bridge       # bridge (shared NAT) or none
    # driver_opts:
    #   mode: shared     # shared (default) or host
    #   gateway: 192.168.105.1/24
    #   dhcp_end: 192.168.105.254
```

### VM naming

Each service is provisioned as a VM named `compose-<projectName>-<serviceName>`. For example, a project named `myproject` with a service named `app` creates a VM called `compose-myproject-app`. You can inspect it with `cakectl infos compose-myproject-app`.

### depends_on

Both short and long forms are supported:

```yaml
# Short form
depends_on:
  - database

# Long form (condition is accepted but not enforced — Caker starts in order regardless)
depends_on:
  database:
    condition: service_healthy
```

### Memory syntax

`deploy.resources.limits.memory` accepts:

| Value | Meaning |
| --- | --- |
| `2048M` / `2048MB` | 2048 MiB |
| `2G` / `2GB` | 2048 MiB |
| `2048` | 2048 MiB (bare integer) |

### Networks

When `driver: bridge` is set and `external` is not `true`, Caker creates a new shared NAT network. A deterministic `/24` subnet is derived from the network name (in the range `192.168.100.x`–`192.168.199.x`) unless you specify a `gateway` in `driver_opts`.

When `external: true`, Caker attaches the service VM to an existing named network instead of creating one.

## Subcommands

> If `caked` is running as a service, use `cakectl compose`. If running `caked` directly (no service), use `caked compose`.

### `compose up`

Start (and create if needed) services in `depends_on` order.

```
cakectl compose up [-f <file>] [--wait-ip-timeout <seconds>] [services...]
caked    compose up [-f <file>] [--wait-ip-timeout <seconds>] [services...]
```

| Flag | Default | Description |
| --- | --- | --- |
| `-f, --file <path>` | auto-detect | Path to compose file |
| `--wait-ip-timeout <seconds>` | `180` | How long to wait for each VM's IP before giving up |
| `[services...]` | all | Limit to specific named services |

If `up` is interrupted or partially fails, the successfully started VMs are recorded. Re-running `compose up` will not attempt to re-create VMs that already exist.

### `compose down`

Stop services in reverse `depends_on` order.

```
cakectl compose down [-f <file>] [--force] [services...]
caked    compose down [-f <file>] [--force] [services...]
```

| Flag | Default | Description |
| --- | --- | --- |
| `-f, --file <path>` | auto-detect | Path to compose file |
| `--force` | off | Force stop without graceful shutdown |
| `[services...]` | all | Limit to specific named services |

### `compose ps`

Show status of services registered under this compose project.

```
cakectl compose ps [-f <file>] [services...]
caked    compose ps [-f <file>] [services...]
```

| Flag | Default | Description |
| --- | --- | --- |
| `-f, --file <path>` | auto-detect | Path to compose file |
| `[services...]` | all | Limit to specific named services |

### `compose rm`

Remove (delete) service VMs and unregister the project.

```
cakectl compose rm [-f <file>] [-s] [--force] [services...]
caked    compose rm [-f <file>] [-s] [--force] [services...]
```

| Flag | Default | Description |
| --- | --- | --- |
| `-f, --file <path>` | auto-detect | Path to compose file |
| `-s, --stop` | off | Stop running services before removing |
| `--force` | off | Do not error if a service VM is not found |
| `[services...]` | all | Limit to specific named services |

### `compose ls`

List all registered compose projects and their service status.

```
cakectl compose ls
```

This command does not need a compose file — it reads the global project registry.

### `compose init`

Write a commented `compose.yml` template in the current directory.

```
cakectl compose init [--force]
caked    compose init [--force]
```

| Flag | Default | Description |
| --- | --- | --- |
| `-f, --force` | off | Overwrite an existing `compose.yml` |

## Differences from Docker Compose

| Feature | Docker Compose | Caker compose |
| --- | --- | --- |
| Runtime | Container daemon | Apple Virtualization.framework VMs |
| VM extensions | No | `disk`, `user`, `password`, `nested`, `autostart`, `sockets` |
| `restart` | Enforced policy | Accepted, not enforced |
| `depends_on` conditions | Enforced | Order only — conditions are accepted but not checked |
| `build:` key | Build from Dockerfile | Not supported — use `image:` with a cloud image URL or simplestream alias |
| Named volumes | Managed by Docker | Not supported — use bind mounts in `volumes:` |
| `--detach` | Background | Always in background (VMs are long-lived) |
| `ls` | Lists containers | Lists registered compose projects |

## Examples

### Start a two-VM stack

```bash
# Initialise
cd myproject
cakectl compose init
# Edit compose.yml…
cakectl compose up
```

### Start only one service

```bash
cakectl compose up app
```

### Rebuild from a custom file path

```bash
cakectl compose up -f ./infra/staging.yml
```

### Inspect a service VM directly

```bash
cakectl infos compose-myproject-app
cakectl exec compose-myproject-app -- uname -a
```

### Tear down and clean up

```bash
# Stop services (keep VMs)
cakectl compose down

# Stop and delete VMs, remove project from registry
cakectl compose rm --stop
```

### List all compose projects

```bash
cakectl compose ls
```
