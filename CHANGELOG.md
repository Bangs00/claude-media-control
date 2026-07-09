# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning is
[SemVer](https://semver.org/spec/v2.0.0.html), tracked in
`.claude-plugin/plugin.json`.

## [Unreleased]

### Added

- `artwork` — save the current track's cover art to a file and display it
  (native path only; the image never enters the conversation as base64).
- `volume` — read or set the system output volume (0–100).
- `statusline` — one-line now-playing segment backed by a 5s TTL cache, gated
  by the `display.statusline` config key. Recipe in `docs/statusline.md`
  (universal wrapper that preserves any existing statusline and appends
  now-playing as its own line).
- `/media:menu` gains **Volume** and **Artwork** actions under "More…".
- SessionStart now also runs an **async build warm-up**, so the first media
  command has no first-run build delay.
- Unit tests (`tests/media.bats`, native stubbed out) and a macOS GitHub
  Actions CI: shellcheck, strict native build, load/symbol smoke test,
  `bats`, and `claude plugin validate --strict`.
- Documentation: full README (how it works, private-API disclaimer,
  requirements, verify, troubleshooting, complete-uninstall guarantee).

## [0.1.0] — 2026-07-09

### Added

- Initial MVP: system-wide now-playing **read and control** on macOS via a
  self-contained MediaRemote bridge (`native/adapter.m` + `native/loader.pl`),
  loaded through `/usr/bin/perl` to pass the macOS 15.4+ entitlement check.
  Ports BSD-3-Clause techniques from ungive/mediaremote-adapter (see
  `native/NOTICE`).
- Subcommands: `now`, `play`, `pause`, `toggle`, `next`, `prev`, `seek`,
  `test`, `config`, `doctor`, `detect`.
- Skills: `now`, `toggle`, `play`, `pause`, `next`, `prev`, `seek`, `menu`
  (interactive remote via AskUserQuestion), `config`, `doctor`.
- Fallback chain: compile-free JXA read and per-app AppleScript control
  (Spotify / Apple Music) when the native helper is unavailable, with a
  `degraded` flag and doctor cross-checks.
- First-run native build cached under `${CLAUDE_PLUGIN_DATA}`, keyed on
  plugin version + macOS build + arch for automatic rebuilds after updates.
- Fail-closed display-feature config (`display.progressbar`,
  `display.statusline`) and a SessionStart detect hook.
