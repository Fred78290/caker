# App Store screenshots

`en-US/` and `fr-FR/` hold the Mac App Store screenshots: 1440×900 PNGs, no
alpha channel (one of the sizes App Store Connect accepts for Mac apps), in
upload order.

They are generated from the raw window captures in `raw/<lang>/` and the
captions in `shots.json`:

```bash
swift Scripts/appstore-screenshots.swift appstore/screenshots/shots.json
```

## Retaking a raw capture

- Launch Caker in the language you need, e.g.
  `open -a Caker --args -AppleLanguages "(fr)" -AppleLocale fr_FR`.
  A running Caker ignores launch arguments, so quit it first. VMs started
  with `caked start <vm>` keep running when Caker quits, but their window
  shows no IP address or CPU/memory meter: for a VM window shot, start the VM
  from Caker itself and wait for the meter to appear.
- Bring the window to the front, so it's captured in its active state.
- Capture it without a shadow (the script draws its own), from a terminal that
  has Screen Recording permission:
  `screencapture -o -x -l <window id> appstore/screenshots/raw/en/home.png`.
  An attached sheet (wizard, Compose editor) is captured with its window.
- The displays used were 1x, so the captures are 1:1 with points. A window
  taller than the space under the headline is cropped at the bottom edge
  (`"fit": "crop"`) rather than scaled, to keep the UI sharp.

`raw/*/linux-vm.png` (Fedora at its login screen) is captured but not in
`shots.json`; add it back once it shows a desktop.
