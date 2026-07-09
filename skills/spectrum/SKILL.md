---
name: spectrum
description: Show a live audio spectrum (frequency bars) of whatever is playing on this Mac. Use when the user asks for a spectrum, visualizer, equalizer, or frequency graph of the current audio. Opt-in feature — needs the system-audio-recording permission.
argument-hint: [--live <seconds>]
allowed-tools: Bash
---

Requested: $ARGUMENTS

Run with Bash (pass the arguments through; no arguments takes a one-shot snapshot):

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" spectrum $ARGUMENTS
```

The command prints a Unicode spectrum line, e.g. `63Hz ▂▄▆█▇▅▃▂ ▃▂▁▁ ▁ 16kHz   (peak: 1.2kHz)`.

- Present the spectrum line(s) verbatim — they are already formatted. `--live <seconds>` streams several frames over that period (Claude Code chat is static text, so this is a scroll, not a smooth animation).
- **Exit 3, "the audio spectrum is off"**: this feature is opt-in. Tell the user to enable it with `/media:config display.spectrum on`, which needs the system-audio-recording permission granted to their terminal app (System Settings > Privacy & Security). Do NOT try to work around the gate.
- **Exit 3, "captured only silence ... permission was revoked"**: the permission was lost and the feature auto-disabled itself; relay that and point to System Settings to re-grant, then `/media:config display.spectrum on`.
- **Exit 3, "nothing is playing"**: there is no audio to visualize right now.
- **Exit 1, "spectrum helper is unavailable"**: needs macOS 14.4+ and Xcode Command Line Tools; suggest `/media:doctor`.

Note the honest limit if asked: the analysis is a local FFT of the system output mix; audio is never stored or transmitted.
