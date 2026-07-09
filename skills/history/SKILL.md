---
name: history
description: Show recently played tracks (a passive local playback log). Use when the user asks what played earlier, what song was on before, recently played music, or to clear the playback history.
argument-hint: [count | clear]
allowed-tools: Bash
---

Requested: $ARGUMENTS

Recent playback history (newest first, `MM-DD HH:MM  title — artist  (app)`):

!`"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" history 20`

Now do the following:

1. If the request is a **number** (e.g. "last 50"), re-run with that count:

   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" history <count>
   ```

2. If the request is to **clear/delete** the history, confirm intent first, then:

   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" history clear
   ```

3. Otherwise present the lines above as a markdown list, newest first —
   `**title** — *artist* (app · MM-DD HH:MM)` — trimmed to what the user asked
   for. If the user asked about a specific track ("when did X play?"), answer
   just that from the list.

Notes you may need:

- Tracks are logged **passively** while media reads happen anyway (statusline
  ticks, `/media:now`, playback commands) — there is no background polling, so
  gaps are normal when Claude Code wasn't running or the statusline is off.
- The log keeps the most recent 500 tracks in `history.jsonl` under the plugin
  data directory; nothing ever leaves the machine.
- Logging is controlled by `/media:config history.record on|off`. If the user
  asks to stop/start recording, use that key.
