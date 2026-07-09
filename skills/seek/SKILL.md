---
name: seek
description: Jump to a specific time position in the currently playing track. Use when the user wants to seek, jump to a timestamp, rewind, fast-forward, or go to a position like 1:30 or 90 seconds.
argument-hint: <seconds | m:ss>
allowed-tools: Bash
---

Requested position: $ARGUMENTS

1. Convert the requested position to absolute seconds:
   - plain number → already seconds (`90` → 90)
   - `m:ss` or `h:mm:ss` → convert (`1:30` → 90, `1:02:30` → 3750)
   - natural language → convert ("1분 30초" / "a minute and a half" → 90)
   - relative requests ("30초 뒤로/앞으로", "skip forward 30s"): first read the
     current position with `"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" now`
     (field `elapsedTimeNow`), then add/subtract and clamp to `[0, duration]`.
2. Run with Bash:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" seek <seconds>
```

The command prints the resulting now-playing JSON. Confirm to the user in one compact markdown line (not a code block) including the new position as `**m:ss** / m:ss` — new position bold (use `elapsedTimeNow` and `duration`).

- If the JSON is `null`: nothing is playing to seek in.
- If the command fails or `"degraded": true` appears: relay the stderr hint briefly (usually `/media:doctor`; degraded seek only works for Spotify/Apple Music).
