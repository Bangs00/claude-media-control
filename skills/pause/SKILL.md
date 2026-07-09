---
name: pause
description: Pause system-wide media playback on this Mac. Use when the user says pause, mute the song for a moment, or hold the music.
allowed-tools: Bash
---

Pause command sent. Resulting state (JSON):

!`"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" pause`

Confirm to the user in one compact markdown line (not a code block): `▶︎|⏸ **<title>** — *<artist>* · <appName>` (title bold, artist italic; expect `⏸`).

- If the JSON is `null`: nothing was playing to pause.
- If `"degraded": true` or a stderr hint appeared: add one short note pointing to `/media:doctor`.
