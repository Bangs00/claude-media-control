# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning is
[SemVer](https://semver.org/spec/v2.0.0.html), tracked in
`.claude-plugin/plugin.json`.

## [0.6.0] — 2026-07-10

### Removed

- **The audio spectrum, entirely** — `/media:spectrum`, the statusline
  `spectrum` item, `native/spectrum.m`, and the `display.spectrum` /
  `spectrum.style` / `spectrum.color` config keys.

  **Why:** the spectrum captured the system output mix with a Core Audio
  process tap, and every Claude Code session ran its own capture. With
  sessions open in several terminal tabs — a completely normal way to use
  Claude Code — the concurrent taps, each building its own aggregate device
  over the same output, conflicted and broke the Mac's audio session. A
  cosmetic visualization must never be able to disrupt the very audio it
  visualizes, and independent sessions have no reliable way to coordinate
  their captures, so the feature is removed rather than gated. This also
  retires the only feature that ever asked for the system-audio-recording
  permission — the plugin now requests no audio-capture permission at all
  (a previously granted one can be revoked in System Settings > Privacy &
  Security).

  Pre-0.6.0 configs stay valid: the removed keys are ignored, and a stored
  `spectrum` statusline item is filtered out on read.

### Added

- **`/media:statusline` — a statusline arrangement picker.** Pick a layout
  from **visual previews** shown next to the options (Standard / Stacked /
  Compact / Everything), or describe any arrangement ("time first", "output
  device in front", "one item per line") and it is mapped onto an ordered
  item list. The same preset picker (plus a "Keep current" option that
  previews your present arrangement) opens inside `/media:config`.
- **Statusline items now render in the order you save them.**
  `statusline.fields` keeps the order it is given — `/media:config
  statusline.fields "time,progressbar,track"` puts the time first. `app`
  still attaches to the track group, and the progress bar + time share a
  group (one line in the stacked layout) when adjacent.

### Changed

- The interactive `/media:config` flow was rebuilt around the layout picker:
  a single layout question with previews replaces the item checkboxes, the
  extras question (and its redundant `None` option — unchecking already means
  "none") is gone, and the output-device item became a checkbox among the
  statusline toggles. Feature toggles (statusline on/off, colors, marquee,
  `/media:now` progress bar, history) are unchanged.

## [0.5.0] — 2026-07-10

### Changed

- **`/media:config` is now interactive.** Running `/media:config` with no
  arguments opens an AskUserQuestion settings picker: check which now-playing
  items the statusline shows (track, app, progress bar, time, output device,
  spectrum), toggle every display feature on/off from radio-style menus
  (statusline segment, separate-line layout, colors, marquee, the
  `/media:now` progress bar, playback history), and pick the spectrum style and
  color. Each on/off setting is a checkbox — checked means on. The text form
  `/media:config <key> on|off` (and `statusline.fields`, `spectrum.style`,
  `spectrum.color`) still works for scripting and one-off changes, so the
  underlying `media.sh config` interface is unchanged.

### Removed

- **`/media:statusline`** — folded into `/media:config`. Everything it did
  (choosing which statusline items appear and their layout) is now part of the
  interactive `/media:config` flow, alongside the display toggles it never
  covered before. Run `/media:config` instead; the `media.sh statusline`
  subcommand that renders the segment is untouched.

## [0.4.0] — 2026-07-09

### Added

- **Playback history** (`/media:history`): a passive local log of played
  tracks. Entries are recorded on reads that happen anyway (statusline ticks,
  `/media:now`, playback re-reads) — no polling, no daemon, no extra resource
  cost. Newest-first listing (`history [count]`, `history --json`), `history
  clear`, a 500-entry cap on `history.jsonl`, and a `history.record` config
  key (default `on`) to stop logging.
- **Output devices** (`/media:output`): list the Mac's audio output devices
  and switch the default one by name, unique case-insensitive substring, or
  1-based list position. Implemented with the public CoreAudio API in the
  native adapter (`adapter_output_list` / `adapter_output_set`) — no extra
  permissions; degraded mode (no native helper) gets a clear refusal.
- Statusline `app` field, **in the default field set**: the playing app after
  the track, e.g. `▶︎ Karma Police — Radiohead (Spotify)`. Previously the app
  name was read but never rendered anywhere in the statusline.
- Statusline `output` field (opt-in via `/media:statusline`): the current
  audio output device (`🔊 AirPods Pro`). The adapter now includes
  `outputDevice` in the now-playing JSON, so the field rides the same read as
  the rest of the segment — no extra process per refresh.
- **Marquee scrolling** for long statusline titles (`statusline.marquee`,
  default `on`): titles wider than 30 display cells scroll through a fixed
  30-cell window, one character per second, in step with the 1-second segment
  cache. CJK characters count as two cells so the window width stays steady.

## [0.3.0] — 2026-07-09

### Added

- `statusline.color` config key (default `on`): the statusline segment is now
  ANSI-styled — state-colored icon and progress-bar fill (green playing /
  yellow paused), bold title, italic artist, dim time. Standard 16-color SGR
  codes only, so the terminal palette stays in charge; the `NO_COLOR`
  environment variable is honored, and `statusline.color off` restores plain
  text.
- `spectrum.style` + `spectrum.color` config keys for the spectrum bars:
  `solid` (default) tints every bar in one configurable color (`red green
  yellow blue magenta cyan white`, default `cyan`); `rainbow` applies a fixed
  front-to-back color cycle by bar position — never by loudness — that
  marches one step per second (`spectrum.color` is then ignored). The tint
  shows in the statusline segment and when `media.sh spectrum` runs directly
  in a terminal; piped/captured spectrum output stays plain.

### Changed

- Skill replies render as styled markdown instead of plain code-block text:
  `/media:now` shows a bold title, italic artist and a bold elapsed time;
  playback confirmations, `/media:menu` state lines, seek/volume replies and
  artwork captions follow the same format.

## [0.2.0] — 2026-07-09

### Added

- **Audio spectrum** (`/media:spectrum`, opt-in): a live frequency-bar view of
  the system output mix, captured with a Core Audio process tap
  (`native/spectrum.m`, public API since macOS 14.4) and analyzed by a local
  vDSP FFT. `snapshot` (one shot) or `--live <seconds>`. No audio is stored or
  transmitted — only the resulting bar string is printed.
- `display.spectrum` config key with a fail-closed enable: the tap is
  exercised, and if it captures only silence while audio is playing the enable
  is refused (the audio-recording grant is missing). Runtime revocation
  auto-disables the feature.
- **Customizable statusline** via `/media:statusline` (interactive): pick which
  items appear — track, progress bar, time, spectrum — with an AskUserQuestion
  picker (select all for everything).
- `statusline.multiline` config key: lay statusline items out on separate lines
  instead of one line.
- Progress bar and the mini spectrum are now available as statusline items.

### Changed

- Statusline segment TTL cut from 5s to 1s so the elapsed time and progress bar
  advance every second (a now-read costs ~60ms). Pair with a small
  `refreshInterval` for idle ticking (see `docs/statusline.md`).

### Fixed

- `json_field` now reads JSON booleans (e.g. `playing`), which the runtime
  permission-revocation downgrade and the spectrum preflight rely on.

### Notes

- The process tap needs a signed binary; clang applies an ad-hoc signature
  automatically on Apple Silicon, which suffices once the terminal app holds the
  "system audio recording" grant. macOS shows no automatic prompt for CLI
  tools, so the permission is granted manually in System Settings > Privacy &
  Security (`/media:doctor` and the skills explain this).
- The spectrum needs macOS 14.4+; on older systems the feature stays hidden and
  never compiles the helper.

## [0.1.0] — 2026-07-09

Initial public release.

### Added

- Initial MVP: system-wide now-playing **read and control** on macOS via a
  self-contained MediaRemote bridge (`native/adapter.m` + `native/loader.pl`),
  loaded through `/usr/bin/perl` to pass the macOS 15.4+ entitlement check.
  Ports BSD-3-Clause techniques from ungive/mediaremote-adapter (see
  `native/NOTICE`).
- Subcommands: `now`, `play`, `pause`, `toggle`, `next`, `prev`, `seek`,
  `test`, `config`, `doctor`, `detect`.
- Skills: `now`, `toggle`, `play`, `pause`, `next`, `prev`, `seek`, `menu`
  (interactive remote via AskUserQuestion), `artwork`, `volume`, `config`,
  `doctor`.
- Fallback chain: compile-free JXA read and per-app AppleScript control
  (Spotify / Apple Music) when the native helper is unavailable, with a
  `degraded` flag and doctor cross-checks.
- First-run native build cached under `${CLAUDE_PLUGIN_DATA}`, keyed on
  plugin version + macOS build + arch for automatic rebuilds after updates.
- Fail-closed display-feature config (`display.progressbar`,
  `display.statusline`) and a SessionStart detect hook.
- `artwork` — save the current track's cover art to a file and display it
  (native path only; the image never enters the conversation as base64).
- `volume` — read or set the system output volume (0–100).
- `statusline` — one-line now-playing segment backed by a 5s TTL cache, gated
  by the `display.statusline` config key. Recipe in `docs/statusline.md`
  (universal wrapper that preserves any existing statusline and appends
  now-playing as its own line).
- SessionStart async build warm-up, so the first media command has no
  first-run build delay.
- Unit tests (`tests/media.bats`, native stubbed out) and a macOS GitHub
  Actions CI: shellcheck, strict native build, load/symbol smoke test,
  `bats`, and `claude plugin validate --strict`.
- Documentation: full README (how it works, private-API disclaimer,
  requirements, verify, troubleshooting, complete-uninstall guarantee).
