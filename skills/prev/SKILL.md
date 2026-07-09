---
name: prev
description: Go back to the previous track in whatever app is playing on this Mac. Use when the user says previous song, go back a track, or replay the last song.
allowed-tools: Bash
---

Went to the previous track. Resulting state (JSON):

!`"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" prev`

Confirm to the user in one compact line: `▶︎|⏸ <title> — <artist> (<appName>)` — this is the track now playing.

- Note: many apps restart the current track on the first "previous" and only jump to the prior track on a second call — mention this if the title did not change.
- If the JSON is `null`: nothing was playing to control.
- If `"degraded": true` or a stderr hint appeared: add one short note pointing to `/media:doctor`.
