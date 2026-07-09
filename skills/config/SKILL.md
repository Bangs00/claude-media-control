---
name: config
description: Show or change media plugin display settings (progress bar, statusline segment) with on/off toggles. Use when the user wants to enable/disable a media display feature or see current media settings.
argument-hint: [key] [on|off]
allowed-tools: Bash
---

Requested change: $ARGUMENTS

Run with Bash (pass the arguments through; no arguments prints the full settings table):

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config $ARGUMENTS
```

Valid keys: `display.progressbar`, `display.statusline`. If the user names a feature loosely ("progress bar", "statusline"), map it to the key.

Rules you must follow:

- Enabling runs a preflight check. Exit code 3 means the feature cannot work right now and the enable was **refused** (fail-closed by design). Explain the reason from stderr, point to `/media:doctor`, and do NOT retry or work around the refusal.
- Disabling always succeeds.
- Afterwards show the resulting state (re-run with no arguments if helpful).
