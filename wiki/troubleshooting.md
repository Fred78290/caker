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
- run `swift build -Xswiftc -D -Xswiftc SPARKLE` from the repository root
- clear derived data/build cache if needed

## Wiki publication fails

Symptoms:
- `publish-wiki.sh` says it cannot access `<repo>.wiki.git`

Checks:
- wiki feature is enabled in GitHub repository settings
- token exists: `GITHUB_TOKEN` or `GH_TOKEN`
- SSH mode if needed: `USE_SSH=1`

## macOS 27 installation fails or stalls

**Symptoms:**
- Installation stalls at ~78% and never completes (App Store build, or host < macOS 26).
- Error: "Couldn't find a restorable device to install onto."
- Installation starts but the VM never shuts down after completion.

**Checks:**

1. **Verify you are using a non-App Store build** — the AMRestore backend is only available outside the App Store. The App Store build falls back to `VZMacOSInstaller`, which is known to fail at ~78% for macOS 27 guests on macOS 26 hosts.

2. **Verify the host is macOS 26 or later** — the AMRestore path requires `macOS 26.0` APIs.

3. **Check whether the ECID can be resolved** — the AMRestore engine identifies the VM by its ECID (embedded in the machine identifier). If Caker logs `"Cannot determine device ECID from VM configuration"`, the VM's machine identifier may be missing or corrupted. Delete and recreate the VM.

4. **Check the restore logs** — four log files are written to `~/Library/Application Support/Caker/VirtualInstall/Logs/`. Review `global.log` first for top-level errors, then `host.log` for the host-side restore trace.

5. **Device not found within 5 seconds** — if Caker logs `"Couldn't find device with ECID <n>"`, the VM did not enter DFU mode in time. Confirm that no other process is holding the VM or preventing it from starting.

6. **Force-enable the AMRestore backend for diagnosis:**
   ```bash
   defaults write com.aldunelabs.Caker CakerForceVirtualInstallBackend -bool true
   ```
   This bypasses the version check and always uses AMRestore, which can help isolate whether the issue is in backend selection or in the restore itself.

7. **Check signing server reachability** — AMRestore personalizes the IPSW against `gs.apple.com:443`. Make sure that host is reachable from the Mac (no corporate firewall or proxy blocking it).

## Useful commands

- `swift build -Xswiftc -D -Xswiftc SPARKLE`
- `GH_TOKEN="${GITHUB_TOKEN}" ./Scripts/publish-wiki.sh Fred78290 caker`
- `USE_SSH=1 ./Scripts/publish-wiki.sh Fred78290 caker`
