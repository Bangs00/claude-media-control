---
name: play
description: Start or resume system-wide media playback on this Mac. Use when the user says play the music, resume playback, or continue the song.
allowed-tools: Bash
---

Play command sent. Resulting state (JSON):

!`"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" play`

Confirm to the user in one compact markdown line (not a code block): `▶︎|⏸ **<title>** — *<artist>* · <appName>` (title bold, artist italic).

- If the JSON is `null`: there is no active media session to resume — the user needs to start playback in an app once first.
- If `"degraded": true` or a stderr hint appeared: add one short note pointing to `/media:doctor`.
