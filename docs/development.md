---
layout: default
title: Development
nav_order: 4
---

# Development

## Code organization

- `Sources/cakectl/Commands/` – CLI command handlers
- `Sources/caked/Commands/` and `Sources/caked/Handlers/` – daemon command and runtime handlers
- `Sources/cakedlib/` – shared utilities, config, and core abstractions

## Tests

Primary test locations:

- `Tests/CakerTests/`
- `Caker/CakerTests/`
- `integration/tests/`

## Contribution workflow

1. Create a branch from `main`.
2. Implement focused changes.
3. Run relevant tests and build checks.
4. Open a pull request with clear context.

Contributor guide:

- [CONTRIBUTING.md](https://github.com/Fred78290/caker/blob/main/CONTRIBUTING.md)

## Web UI

Caker includes a React-based web UI located in the `webui/` directory. It is built with Vite, TypeScript, and Bootstrap 5.

### Requirements

- Node.js ≥ 18
- npm ≥ 9

### Install dependencies

```bash
cd webui
npm install
```

### Development mode

Start the Vite dev server with a proxy to a locally running `caked`:

```bash
cd webui
npm run dev
```

The dev server listens on `http://localhost:5173`. API calls to `/1.0` are proxied to `http://127.0.0.1:8080` by default. Override the target with the `VITE_API_TARGET` environment variable:

```bash
VITE_API_TARGET=http://127.0.0.1:9090 npm run dev
```

### Production build

```bash
cd webui
npm run build
```

The output is written to `webui/dist/`. Pass this directory to `caked` with the `--web-ui` flag:

```bash
caked service --rest --web-ui /path/to/caker/webui/dist
```

The UI is then served at `http://<host>:<port>/ui`.

### Deploying from a zip archive

`--web-ui` also accepts a `.zip` archive. `caked` extracts it automatically at startup to a temporary directory:

```bash
cd webui && npm run build && zip -r ../webui-dist.zip dist/
caked service --rest --web-ui /path/to/webui-dist.zip
```

If the archive contains a single top-level directory (e.g. `dist/`), `caked` descends into it automatically so the index file is resolved correctly.

### Project structure

```
webui/
  index.html            # HTML entry point
  vite.config.ts        # Vite configuration (base /ui/, proxy /1.0)
  tsconfig.json         # TypeScript configuration
  src/
    main.tsx            # React entry point (Bootstrap CSS/JS imported here)
    App.tsx             # HashRouter + routes
    types/lxd.ts        # TypeScript interfaces matching the REST API
    api/                # axios API client modules
    components/         # Shared UI components (Layout, StatusBadge, …)
    pages/              # One component per page
  dist/                 # Production output (after npm run build)
```

## Useful scripts

- `Scripts/build-signed-debug.sh` - Build debug version with signing
- `Scripts/build-signed-release.sh` - Build release version with signing
- `Scripts/build-signed-snapshot.sh` - Build package and dmg with signing
- `Scripts/act.sh` - Local GitHub Actions testing
- `Scripts/run-signed-caked.sh` - Run signed daemon
- `Scripts/run-signed-cakectl.sh` - Run signed CLI

## Development Environment

### Requirements
- macOS (required for Virtualization framework)
- Xcode with Swift toolchain
- Signing certificates and provisioning profiles
- Optional: GitHub CLI for pull request management

### Getting Started
1. Clone the repository
2. Run `./Scripts/build-signed-debug.sh` to build
3. Use the run scripts to test components
4. Run tests via Xcode or command line

### Code Style
- Follow Swift conventions
- Use clear, descriptive naming
- Add documentation for public APIs
- Include tests for new functionality