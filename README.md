# claude-media-control

[![CI](https://github.com/Bangs00/claude-media-control/actions/workflows/ci.yml/badge.svg)](https://github.com/Bangs00/claude-media-control/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![macOS](https://img.shields.io/badge/platform-macOS-black)
![Claude Code plugin](https://img.shields.io/badge/Claude%20Code-plugin-d97757)
![Zero dependencies](https://img.shields.io/badge/dependencies-zero-brightgreen)

**English** | [한국어](README.ko.md) | [日本語](README.ja.md) | [简体中文](README.zh-CN.md)

See and control **whatever is playing on your Mac** — Spotify, Apple Music,
browsers, VLC — right from Claude Code. Ask "what song is this?", say "pause
the music", or open an interactive remote. No OAuth, no API keys, no per-app
integrations, and **nothing to install with Homebrew**.

![claude-media-control demo](docs/demo.gif)

## Why this one

The existing Claude/Spotify/Apple-Music integrations each lock you into one
app and an OAuth/AppleScript setup. This plugin talks to the **macOS
system-wide now-playing service**, so it sees and controls the *currently
active* player no matter which app it is — with **zero third-party
dependencies**. The only requirement is the Xcode Command Line Tools, which
you already have if you can `git clone` (see [Requirements](#requirements)).

## Install

Two lines inside Claude Code — no Homebrew step:

```
/plugin marketplace add Bangs00/claude-media-control
/plugin install media@claude-media-control
```

The first media command builds a tiny native helper (~2s, once); after that
it is cached. macOS only.

## Usage

Natural language, slash commands, or an interactive menu — all work:

| Say this | …or run | What happens |
| --- | --- | --- |
| "what song is playing?" | `/media:now` | current title / artist / app + progress bar |
| "pause the music" | `/media:pause` · `/media:toggle` | pause / resume the active player |
| "next track" | `/media:next` · `/media:prev` | skip / go back |
| "jump to 1:30" | `/media:seek 1:30` | seek to an absolute position |
| "show the album art" | `/media:artwork` | saves the cover and displays it |
| "turn it down" | `/media:volume 30` | read / set system output volume (0–100) |
| "what played earlier?" | `/media:history` | recently played tracks (passive local log) |
| "switch to my AirPods" | `/media:output airpods` | show / switch the audio output device |
| "give me a remote" | `/media:menu` | interactive controller (arrow-key menu) |
| "arrange my statusline" | `/media:statusline` | pick a layout from visual previews, or place any item on any line with a numeric pattern |
| "configure the statusline" | `/media:config` | interactive settings — layout plus every display toggle (progress bar, history, colors, marquee) |
| — | `/media:doctor` | diagnose build / permissions / fallbacks |

Optional: put now-playing in your statusline — see
[docs/statusline.md](docs/statusline.md). `/media:statusline` shows the
layouts as **visual previews** and lets you arrange the items (track, app,
volume, progress bar, time, output device) in any order, on any lines — pick
the Standard or Stacked preset, or go `Custom…` and type a numeric pattern
like `123/456` straight into the chat: digits name the items, `/` starts a
new line, and digit order is display order. "time first" or "output device
in front" works too, because items render in exactly the order you save
them. The volume item shows icon + level bar + percent (`🔉 ▄ 45%`), the
output item's icon follows the device kind (`🎧` Bluetooth, `📺` HDMI, `📶`
AirPlay, `🔊` speakers), titles wider than 30 cells scroll marquee-style
(`statusline.marquee`), and the segment comes ANSI-styled — state-colored
icon and progress bar, bold title and elapsed time, italic artist —
`/media:config statusline.color off` (or `NO_COLOR`) restores plain text.

## How it works

macOS has no public API to read another app's now-playing info; the private
`MediaRemote` framework does, but since macOS 15.4 its daemon only answers
processes signed by Apple. This plugin uses the same technique as
[ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter):
a small Objective-C helper (`native/adapter.m`) is loaded by
`/usr/bin/perl` — an Apple platform binary — which passes the entitlement
check. Playback commands and seeking go through the same path.

If the native helper can't build (no Command Line Tools), the plugin falls
back to a compile-free read via `osascript`/JXA, and to per-app AppleScript
for control of Spotify and Apple Music. `/media:doctor` tells you which mode
you're in.

> **Disclaimer.** This relies on a **private, undocumented Apple framework**.
> It works today on macOS 26.x and is re-validated automatically after every
> macOS update (the build cache is keyed on the OS build number), but Apple
> could change or block it at any time. When that happens the plugin degrades
> to the fallback paths and `/media:doctor` reports it. No warranty — see
> [LICENSE](LICENSE).

## Playback history & output devices

`/media:history` lists what played recently, newest first. Tracks are logged
**passively** while media reads happen anyway (statusline ticks, `/media:now`,
playback commands) — no background polling, no daemon, no extra resource cost.
The log keeps the latest 500 tracks in the plugin data directory and never
leaves your machine; `/media:config history.record off` stops logging and
`/media:history clear` wipes it.

`/media:output` shows every audio output device and switches between them
("play it on my AirPods") through the public CoreAudio API — no extra
permissions. The statusline can show the active device too: check "Output
device item" in `/media:config`, or place it anywhere with `/media:statusline`.

## Requirements

- **macOS** (tested on macOS 26.x / Apple Silicon; the technique targets
  15.4+). Other OSes are on the roadmap.
- **Xcode Command Line Tools** — for the one-time native build. Install with
  `xcode-select --install`. You almost certainly already have them: cloning
  a plugin needs `git`, which ships with the same Command Line Tools as
  `clang`. Without them the plugin still runs in fallback mode.

No Homebrew, no Node, no Python, no API keys.

## Verify installation

```
/media:doctor
```

A healthy install ends with `verdict: PRIMARY OK`. If it says `DEGRADED`,
the report names the fix (usually `xcode-select --install`, then
`/media:doctor --rebuild`).

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `DEGRADED — native helper unavailable` | `xcode-select --install`, then `/media:doctor --rebuild` |
| `PRIMARY READ LIKELY BLOCKED` after a macOS update | `/media:doctor --rebuild`; if it persists, please [open an issue](https://github.com/Bangs00/claude-media-control/issues) |
| AppleScript control fails with **error -1743** | approve your terminal app under System Settings → Privacy & Security → Automation (fallback mode only) |
| Nothing plays but `now` shows a track | the app reported stale state; try `/media:next` or restart the player |

Build logs live at `${CLAUDE_PLUGIN_DATA}/build.log`.

## Uninstall

```
/plugin uninstall media@claude-media-control
/plugin marketplace remove claude-media-control
```

This **fully reverts your machine to its pre-install state.** Everything the
plugin creates lives in two Claude-managed directories
(`~/.claude/plugins/cache/...` and `~/.claude/plugins/data/...`), both removed
on uninstall — no LaunchAgents, no login items, no home-directory files, no
`settings.json` edits, no system packages. The plugin never writes anywhere
else; temporary artwork goes to `$TMPDIR`, which macOS clears on its own.

Two things are *not* plugin files and may remain (both harmless):

- If you used the AppleScript fallback, macOS keeps its **Automation approval**
  ("terminal → Spotify/Music") in the system permission database. Clear it
  with `tccutil reset AppleEvents` if you like.
- If you added the optional statusline wrapper, remove
  `~/.claude/statusline-media.sh` and restore your previous `"statusLine"`
  value in `settings.json`.

## Roadmap

- **Linux** backend via `playerctl`/MPRIS — the dispatcher is already
  structured for per-OS backends; contributions welcome.
- **Windows** backend via SMTC (`GlobalSystemMediaTransportControls`) —
  contributions welcome.

## Development

```bash
claude --plugin-dir .          # load the plugin from a checkout
shellcheck scripts/*.sh        # lint
npx bats tests/media.bats      # unit tests (native stubbed out)
claude plugin validate . --strict
```

CI runs all of the above plus a strict native build on a macOS runner.

## License

[MIT](LICENSE). The native adapter ports BSD-3-Clause techniques from
ungive/mediaremote-adapter and references CLI/JSON conventions from
ungive/media-control — see [native/NOTICE](native/NOTICE).
