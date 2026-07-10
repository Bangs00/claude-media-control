---
name: now
description: Show what's currently playing on this Mac (any app — Spotify, Apple Music, browsers). Use when the user asks what song/track/music is playing, who the artist is, or wants playback status.
allowed-tools: Bash
---

Current system-wide now-playing state (JSON):

!`"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" now`

Progress bar display setting (on/off):

!`"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config display.progressbar`

Progress bar characters (`style.progressbar.style`):

!`"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config style.progressbar.style`

Present the state to the user exactly in this format, as plain markdown lines — NOT inside a code block, so the bold/italic styling renders:

- Line 1: `▶︎ **<title>** — *<artist>* · <appName>` — use `▶︎` when `playing` is true, `⏸` when false; title bold, artist italic. If `appName` is missing, use `bundleIdentifier`.
- Line 2 (only when the progress bar setting is `on` AND `duration` is present): a 20-char bar of filled (elapsed) + empty (remaining) characters using the ratio `elapsedTimeNow / duration`, then two spaces and `**m:ss** / m:ss` (elapsed time bold). The bar characters follow the bar-style value above — `line` → `━`/`─`, `blocks` → `█`/`░`, `wave` → `~`/`-`, `dots` → `●`/`○`, any other two-character value → first char filled, second empty — so this bar matches the statusline segment. The elapsed `m:ss` is ALWAYS `elapsedTimeNow` (use `elapsedTime` only when `elapsedTimeNow` is absent) — `elapsedTime` is the app's last snapshot and can lag minutes behind; the statusline segment shows `elapsedTimeNow`, so anything else here would contradict it. The total `m:ss` is `duration`.
- If `duration` is absent (live stream): skip the bar, show `**m:ss** / LIVE` (same elapsed rule).
- If the JSON is `null`: tell the user nothing is playing right now.
- If the JSON contains `"degraded": true` or a stderr hint appeared: add one short note that the plugin is in fallback mode and `/media:doctor` has details.

Example (the markdown you output):

```markdown
▶︎ **Neon Horizon** — *Midnight Arcade* · Firefox
━━━━━━━━━━━─────────  **2:07** / 3:48
```
