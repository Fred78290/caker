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

## Useful scripts

- `Scripts/build-signed-debug.sh`
- `Scripts/build-signed-release.sh`
- `Scripts/act.sh`
