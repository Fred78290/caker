# App Store app previews

`en-US/` and `fr-FR/` hold four Mac App Store app previews per language:
1920×1080 (the only size App Store Connect accepts for Mac previews), 30 fps
H.264 with a silent stereo AAC track, 20 to 27 seconds each (the limit is 15
to 30).

1. `01-virtual-machines.mp4`: home mosaic, list view and detail pane, then a
   macOS VM window with its live CPU and memory meters.
2. `02-create-vm.mp4`: the new VM wizard, from picking a cloud image to adding
   a port forward.
3. `03-compose-images-networks.mp4`: the Compose editor, cloud image servers
   and network settings.
4. `04-command-line.mp4`: a Terminal session with `caked aliases`,
   `cakectl list`, then `cakectl start`, `exec` and `infos` on a VM.

App Store Connect takes at most three previews per language, so upload three
of the four.

Apple requires previews to be recordings of the app itself, so each one is a
real recording of Caker.app, edited only with cuts, a background and captions.

They are built from window recordings in `raw/<lang>/` (git-ignored: ProRes,
hundreds of MB each) and the captions and trim points in `previews.json`:

```bash
swift Scripts/appstore-previews.swift appstore/previews/previews.json
```

The composer needs `ffmpeg` (`brew install ffmpeg`) for the audio track.

## Recording a clip

```bash
swiftc -O Scripts/appstore-record.swift -o /tmp/appstore-record
/tmp/appstore-record appstore/previews/raw/en/home.mov <x> <y> <width> <height> <seconds>
screencapture -o -x -l <window id> appstore/previews/raw/en/home.png
```

- Record exactly the window's frame (its position and size in screen points),
  from a terminal with Screen Recording permission. Only Caker's windows are
  captured, without the cursor, so you can drive the app while it records.
- Take the still right after: it gives the window's rounded shape and shadow.
- The recorder takes one screenshot after another instead of running a capture
  stream. During a stream, macOS swaps the window's traffic lights for a purple
  "recording" indicator; single screenshots don't trigger it.
- Launch Caker in the language you record (`open -a Caker --args
  -AppleLanguages "(fr)" -AppleLocale fr_FR`, quitting it first) and keep the
  window in front.
- For the VM window, start the VM from Caker itself: a VM started with
  `caked start` gets a window without its IP address and CPU/memory meters.
- Each language is recorded separately, so `in`/`out` in `previews.json` can
  be set per language. A contact sheet helps find them:
  `ffmpeg -i raw/en/tour.mov -vf "fps=2,scale=200:-1,tile=8x8" -frames:v 1 sheet.png`.

## Recording the command-line preview

`cli-demo.sh` is the Terminal session: it types each command at a human pace,
then runs it for real. Open it in Terminal.app (`open -a Terminal`, with
`CAKER_APP` pointing at the Caker.app to use), with a `caked service listen`
running for cakectl. It sizes its window from `DEMO_COLS`/`DEMO_ROWS` (158
columns fits the `cakectl list` table) and waits for its trigger file, so:

1. enlarge the font with View > Bigger (it only affects that window),
2. take the still and start the recorder with `CAKER_BUNDLE_ID=com.apple.Terminal`,
3. `touch /tmp/caker-cli-demo.go`.

The clip is cropped below the title bar (`"crop"` in `previews.json`), which
shows the account name. Keep the window away from other Terminal windows: a
translucent profile shows them through it. For the English take, cakectl and
the daemon need English output: `defaults write
~/Library/Preferences/com.aldunelabs.caker.cakectl AppleLanguages -array en`
(and the same for `com.aldunelabs.caker.caked`, then restart the daemon), and
delete the key again afterwards. The VM boot is cut with `"join": true` clips,
since the screen doesn't change while it waits.
