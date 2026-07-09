---
name: next
description: Skip to the next track in whatever app is playing on this Mac. Use when the user says next song, skip this track, or change the song.
allowed-tools: Bash
---

Skipped to the next track. Resulting state (JSON):

!`"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" next`

Confirm to the user in one compact line: `▶︎|⏸ <title> — <artist> (<appName>)` — this is the track now playing.

- If the JSON is `null`: nothing was playing to skip.
- If `"degraded": true` or a stderr hint appeared: add one short note pointing to `/media:doctor`.
