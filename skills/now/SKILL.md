---
name: now
description: Show what's currently playing on this Mac (any app — Spotify, Apple Music, browsers). Use when the user asks what song/track/music is playing, who the artist is, or wants playback status.
allowed-tools: Bash
---

Current system-wide now-playing state (JSON):

!`"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" now`

The progress bar, already rendered (empty when the bar is switched off, when nothing is playing, or when the track has no duration):

!`"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" bar`

Present the state to the user exactly in this format, as plain markdown lines — NOT inside a code block, so the bold/italic styling renders:

- Line 1: `▶︎ **<title>** — *<artist>* · <appName>` — use `▶︎` when `playing` is true, `⏸` when false; title bold, artist italic. If `appName` is missing, use `bundleIdentifier`.
- Line 2 (only when the bar above is non-empty): the bar copied **verbatim**, then two spaces and `**m:ss** / m:ss` (elapsed time bold). Never redraw the bar, re-space it, change its width, or substitute its characters — `media.sh bar` is the same builder that draws the statusline segment, and copying it byte-for-byte is what keeps the two surfaces agreeing. Most presets cannot be reproduced by hand anyway: they are computed waveforms whose glyphs depend on the playback position.
- The elapsed `m:ss` is ALWAYS `elapsedTimeNow` (use `elapsedTime` only when `elapsedTimeNow` is absent) — `elapsedTime` is the app's last snapshot and can lag minutes behind; the statusline segment shows `elapsedTimeNow`, so anything else here would contradict it. The total `m:ss` is `duration`.
- If `duration` is absent (live stream): the bar comes back empty; show `**m:ss** / LIVE` (same elapsed rule).
- If the JSON is `null`: tell the user nothing is playing right now.
- If the JSON contains `"degraded": true` or a stderr hint appeared: add one short note that the plugin is in fallback mode and `/media:doctor` has details.

Example (the markdown you output):

```markdown
▶︎ **Neon Horizon** — *Midnight Arcade* · Firefox
━━━━━━━━━━━─────────  **2:07** / 3:48
```
