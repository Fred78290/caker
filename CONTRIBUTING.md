# Contributing to Caker

Thanks for contributing to Caker.

This document explains the expected workflow for code changes, tests, documentation, and wiki updates.

## Branching model

- Primary development branch: `main`
- Open pull requests against `main` unless maintainers explicitly ask for another target.
- Keep PRs focused and small enough to review quickly.

## Development setup

### Prerequisites

- macOS
- Xcode and Swift toolchain compatible with this repository
- Access to required signing assets when using signed build scripts

### Build

From repository root:

- Debug signed build: `./Scripts/build-signed-debug.sh`
- Release signed build: `./Scripts/build-signed-release.sh`
- Swift package build: `swift build`

### Tests

- Run package tests: `swift test`

If your change impacts integration behavior, also run the relevant tests under `integration/tests/`.

## Where to change code

- `Sources/caked/` → daemon/service side
- `Sources/cakectl/` → CLI client side
- `Sources/cakedlib/` → shared core logic
- `Sources/grpc/` → gRPC contracts/generated client-server bindings

When introducing a command, keep parity between `caked` and `cakectl` when applicable.

## Command behavior guidelines

- Commands use `ArgumentParser` and should provide clear `CommandConfiguration` metadata.
- Prefer explicit help text and safe defaults.
- If `caked` is running as a service, operational usage should go through `cakectl` rather than direct `caked` command execution.

## Coding guidelines

- Keep changes scoped to the feature or fix.
- Avoid unrelated refactors in the same PR.
- Follow existing project style and naming patterns.
- Preserve backward-compatible behavior unless the PR clearly documents a breaking change.

## Pull request checklist

Before opening a PR:

1. Build succeeds locally (`swift build` and/or signed scripts when relevant).
2. Tests pass for impacted areas (`swift test` and targeted integration tests if needed).
3. Command help/output remains coherent for CLI-affecting changes.
4. Documentation/wiki updated when behavior, commands, or workflows changed.
5. PR description includes:
	 - what changed
	 - why it changed
	 - how it was validated

## CI workflow policy

To avoid running privileged or costly automation from pull requests, workflows must not execute on PR events.

- Do not add `pull_request` or `pull_request_target` triggers unless maintainers explicitly approve it.
- Keep default execution to `push` (and `workflow_dispatch` when manual runs are needed).
- Add a defensive job-level guard in workflows:
	- `if: ${{ github.event_name != 'pull_request' && github.event_name != 'pull_request_target' }}`

## Documentation and wiki updates

Wiki source lives in the local `wiki/` folder.

- Publish manually:
	- `GH_TOKEN="$GITHUB_TOKEN" ./Scripts/publish-wiki.sh <owner> <repo>`
	- or `USE_SSH=1 ./Scripts/publish-wiki.sh <owner> <repo>`
- Add release notes entry template quickly:
	- `./Scripts/new-wiki-release-entry.sh`
- Generate release note summary from git log:
	- `./Scripts/update-wiki-release-notes-from-git.sh`

Wiki publication is also automated via GitHub Actions workflow in `.github/workflows/publish-wiki.yaml`.

## Security and secrets

- Never commit credentials, private keys, or signing secrets.
- Use repository or organization secrets in CI (for example `WIKI_TOKEN`).
- Sanitize logs and error output before sharing externally.

## Reporting issues

When reporting a bug, include:

- environment (macOS version, Xcode/Swift version)
- command(s) executed
- expected behavior
- actual behavior and logs/errors
- reproduction steps

Thanks again for helping improve Caker.
