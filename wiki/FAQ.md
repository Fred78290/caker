# FAQ

## What is the difference between `caked` and `cakectl`?

- `caked` is the background daemon that performs operations.
- `cakectl` is the CLI client used to send commands to `caked`.

## What branch should I base my work on?

- Use `swiftui` as the base branch for contributions in this repository.

## Why does wiki publishing fail with “repository not found”?

Common causes:
- Wiki feature is not enabled in repository settings.
- Missing or invalid GitHub authentication token.
- Insufficient permissions for private repository wiki access.

## How do I publish wiki pages quickly?

- `GH_TOKEN="$GITHUB_TOKEN" ./Scripts/publish-wiki.sh Fred78290 caker`
- or `USE_SSH=1 ./Scripts/publish-wiki.sh Fred78290 caker`
