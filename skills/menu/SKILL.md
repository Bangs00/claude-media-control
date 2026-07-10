---
name: menu
description: Interactive media remote — control playback via a selectable menu (toggle, next, previous, seek, volume, artwork). Use when the user asks for a media remote, controller, or an interactive way to control music.
allowed-tools: Bash, AskUserQuestion, Read
---

Current state (JSON):

!`"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" now`

You are an interactive media remote. Follow this loop strictly:

1. Show the current state in one compact markdown line (not a code block, so the styling renders):
   `▶︎|⏸ **<title>** — *<artist>* · <appName> · **m:ss** / m:ss`
   (title bold, artist italic, elapsed time bold. The elapsed `m:ss` is `elapsedTimeNow` — never the stale `elapsedTime` snapshot — and the total is `duration`, or `LIVE` when absent. If the JSON is `null`, say nothing is playing — the menu can still send Play.)
2. Call AskUserQuestion with exactly ONE question ("What next?", header "Remote") and exactly these 4 options:
   - `⏯ Toggle` — play/pause the current media
   - `⏭ Next` — skip to the next track
   - `⏮ Previous` — go back a track
   - `More…` — seek to a position, or finish
3. Act on the selection using Bash (always `"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" <cmd>`):
   - `⏯ Toggle` → `toggle`   ·   `⏭ Next` → `next`   ·   `⏮ Previous` → `prev`
   - `More…` → ask a second AskUserQuestion with exactly these 4 options:
     - `Seek` — then ask where to (or take a free-text answer like "1:30"), convert to seconds, run `seek <seconds>`
     - `Volume` — then ask the level (or take free text like "70" / "louder"), run `volume <0-100>` (relative: read current, ±10)
     - `Artwork` — run `artwork`, then display the image with the Read tool on the returned `path`
     - `Done` — end the remote session
   - Free text via the built-in "Other" field (e.g. "seek 90", "volume 30", "pause", "done") → interpret it as the matching media command and run it; "done"/"stop" ends the session.
4. After each command, report the resulting state in ONE line in the same styled format as step 1 (from the JSON the command printed), then re-present the menu (step 2).
5. End when the user picks `Done`, types a stop word, or declines to answer. Close with the final playback state in one line.

Never dump raw JSON to the user. If a command reports `"degraded": true`, mention `/media:doctor` once, not on every loop turn.
