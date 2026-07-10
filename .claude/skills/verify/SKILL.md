---
name: verify
description: How to verify media.sh changes end-to-end on a real Mac — isolated data dir, real native build, and a controllable fake now-playing app (no dependency on the user's music apps).
---

# Verifying claude-media-control

Surface = the `scripts/media.sh` CLI + the statusline segment it prints.
`npx bats tests/media.bats` covers logic with stubs; real verification runs
the actual pipeline (perl loader → adapter.dylib → mediaremoted).

## Isolate from the user's live install

Always export a scratch data dir first — without it, `media.sh` falls back to
`~/.claude/plugins/data/media-*` and mutates the user's real config/cache:

```bash
export CLAUDE_PLUGIN_DATA=/tmp/media-verify-data
scripts/build-native.sh --rebuild   # real dylib for this checkout's version
```

## Publish a controllable now-playing track

Don't drive Music.app via AppleScript (`tell app "Music" to …` hangs on the
Automation-consent dialog in headless contexts, and you can't control track
titles). Instead compile a tiny publisher: MPNowPlayingInfoCenter +
MPRemoteCommandCenter handlers + a silent AVAudioEngine source node
(`clang -fobjc-arc -framework Foundation -framework MediaPlayer -framework
AVFoundation npub.m -o npub`). Publish any title/artist/duration you need
(long titles for marquee, CJK for width handling).

Two gotchas:

- `appName`/`bundleIdentifier` only appear when the publisher runs from a
  real `.app` bundle **launched via `open`** (LaunchServices registration);
  a bare executable publishes metadata but no app identity.
- Kill it with `pkill -f <name>`; `media.sh now` must return `null` after.

## What to drive

- `media.sh now` — JSON incl. `outputDevice`, `appName`
- `media.sh statusline` after `config display.statusline on` — run twice with
  `sleep 2` between to see the marquee advance; `NO_COLOR=1` and
  `statusline.multiline on` are cheap probes
- Statusline **wiring** (`statusline install/uninstall/status`, the
  auto-wire in `config display.statusline on`, and the wrapper's uninstall
  self-heal) writes to `$HOME/.claude/settings.json` — export a scratch
  `HOME` too before driving it, or you will rewire the user's real
  settings. Simulate "plugin uninstalled" for the self-heal by emptying
  `$HOME/.claude/plugins/installed_plugins.json` (`{"plugins":{}}`) and
  making the recorded dev root non-executable/absent; the wrapper must
  restore `settings.json` and delete itself + the backup.
- `media.sh output` / `output "<substring>"` / `output <n>` — switch to the
  CURRENT device for a safe no-op, or switch away and back; `output "LG"`
  style ambiguous names must exit 4 with candidates
- `media.sh history` / `history --json` — entries appear only on track
  change (dedup across statusline ticks)
- `media.sh doctor` — check the `Output dev` line and `verdict:`

`cat` may be aliased to `bat` in the user's shell — use `/bin/cat -v` to show
SGR codes.

## Restore

Volume, default output device, and any launched apps must match the
pre-test state; the statusline cache lives in the scratch dir and dies
with it.
