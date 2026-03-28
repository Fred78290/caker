# Troubleshooting

## Build signed scripts fail

Symptoms:
- `./Scripts/build-signed-debug.sh` or `./Scripts/build-signed-release.sh` exits with an error

Checks:
- provisioning profile exists in `Resources/`
- entitlements files are present and valid
- local Xcode signing identity is configured

## Swift package resolution issues

Symptoms:
- dependency resolution loops or fails

Checks:
- run package resolution again from Xcode
- run `swift build` from the repository root
- clear derived data/build cache if needed

## Wiki publication fails

Symptoms:
- `publish-wiki.sh` says it cannot access `<repo>.wiki.git`

Checks:
- wiki feature is enabled in GitHub repository settings
- token exists: `GITHUB_TOKEN` or `GH_TOKEN`
- SSH mode if needed: `USE_SSH=1`

## Useful commands

- `swift build`
- `GH_TOKEN="$GITHUB_TOKEN" ./Scripts/publish-wiki.sh Fred78290 caker`
- `USE_SSH=1 ./Scripts/publish-wiki.sh Fred78290 caker`
