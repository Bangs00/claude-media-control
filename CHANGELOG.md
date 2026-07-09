# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning is
[SemVer](https://semver.org/spec/v2.0.0.html), tracked in
`.claude-plugin/plugin.json`.

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
