# Command Summary

This page summarizes the `ArgumentParser` commands implemented in:
- `Sources/caked/Commands`
- `Sources/cakectl/Commands`

## Command model

- `caked` is the local daemon/hypervisor command surface.
- `cakectl` is the gRPC client command surface.
- Most VM/image/network operations exist on both sides with similar names.

## Common command groups (`caked` and `cakectl`)

### VM lifecycle and execution

- `build` — create a VM from options.
- `launch` — build and start a VM.
- `start` / `stop` / `restart` / `suspend` — control VM runtime state.
- `delete` / `duplicate` / `rename` / `configure` — manage VM lifecycle and configuration.
- `list` / `infos` / `waitip` — inspect VM inventory, details, and IP readiness.
- `exec` / `sh` — execute commands in guest VM context.
- `mount` / `umount` — manage VM mounts.

### Images and registries

- `image` group: `list`, `info`, `pull`.
- `pull` / `push` — transfer VM images.
- `login` / `logout` — registry authentication.
- `remote` group: `add`, `delete`, `list`.
- `template` group: `create`, `delete`, `list`.
- `purge` — cleanup caches/images according to retention/budget options.

### Networks

- `networks` group: `infos`, `list`, `create`, `configure`, `delete`, `start`, `stop`.

## `caked`-specific commands

- `certificates` group:
  - `get` — show certificate paths
  - `generate` — generate TLS certs
  - `agent` — generate agent certs
- `service` — service/daemon management entry point.
- `vmrun` — internal VM runtime command (hidden/internal).
- `import` — import external VM from file/URL.
- `networks` extra internal/admin subcommands:
  - `nat-infos`
  - `set-dhcp-lease`
  - `restart`
  - `run` (internal)

## `cakectl`-specific commands

- `grandcentraldispatch` — stream global status updates from daemon dispatcher.

## Notes

- Some commands are internal or hidden in help output on `caked` (`vmrun`, some `networks` subcommands).
- Exact flags/options are defined in the corresponding `*Options` types and command files.
- If the `caked` service is already active, do not run `caked` commands directly; use `cakectl` to interact with the running service.
