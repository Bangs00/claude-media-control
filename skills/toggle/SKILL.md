---
name: toggle
description: Toggle play/pause for whatever media is playing system-wide on this Mac. Use when the user says pause the music, stop the song, resume, unpause, or toggle playback.
allowed-tools: Bash
---

Play/pause toggled. Resulting state (JSON):

!`"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" toggle`

Confirm to the user in one compact markdown line (not a code block): `▶︎|⏸ **<title>** — *<artist>* · <appName>` (title bold, artist italic; `▶︎` when `playing` is true, `⏸` when false).

- If the JSON is `null`: nothing was playing to control.
- If `"degraded": true` or a stderr hint appeared: add one short note pointing to `/media:doctor`.
