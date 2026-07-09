---
name: volume
description: Show or set the Mac's system output volume (0-100). Use when the user asks how loud the volume is, wants it louder/quieter, sets a specific level, or asks to mute.
argument-hint: [0-100]
allowed-tools: Bash
---

Requested volume: $ARGUMENTS

1. Work out the target:
   - no argument → just read the current volume
   - a number 0-100 → set that level
   - relative ("louder", "quieter", "볼륨 올려/내려", "a bit louder") → read the
     current level first, then add/subtract 10 (clamp to [0, 100])
   - "mute" → set 0; "unmute" without a remembered level → suggest 50
2. Run with Bash:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" volume            # read
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" volume <0-100>    # set, then reads back
```

The command prints `{"volume":N,"muted":bool}`. Confirm in one short line,
e.g. `🔊 Volume: 45%` (add `(muted)` when `muted` is true). This is the
system output volume — it does not change per-app sliders.
