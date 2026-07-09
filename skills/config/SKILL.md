---
name: config
description: Show or change media plugin display settings (progress bar, statusline segment, audio spectrum, statusline layout) with on/off toggles. Use when the user wants to enable/disable a media display feature or see current media settings.
argument-hint: [key] [on|off]
allowed-tools: Bash
---

Requested change: $ARGUMENTS

Run with Bash (pass the arguments through; no arguments prints the full settings table):

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config $ARGUMENTS
```

Valid keys:

- `display.progressbar` — progress bar in `/media:now` output
- `display.statusline` — the statusline now-playing segment
- `display.spectrum` — the audio spectrum (opt-in; enabling needs the system-audio-recording permission)
- `statusline.multiline` — statusline layout: `on` = each item on its own line, `off` = one line
- `statusline.color` — ANSI colors/bold/italic in the statusline segment (default `on`; the `NO_COLOR` env var also disables it)
- `spectrum.style` — spectrum bar coloring: `solid` (default, one color) or `rainbow` (fixed front-to-back color cycle by bar position — never amplitude)
- `spectrum.color` — the solid spectrum color: `red green yellow blue magenta cyan white` (default `cyan`; ignored when style is `rainbow`)

`spectrum.style`/`spectrum.color` take those word values instead of on/off. If the user asks for a rainbow/unicorn spectrum → `spectrum.style rainbow`; a specific color ("make the spectrum magenta") → `spectrum.color magenta` (plus `spectrum.style solid` if it was rainbow).

If the user names a feature loosely ("progress bar", "spectrum", "statusline"), map it to the key. To pick **which items** the statusline shows, use `/media:statusline` (interactive) rather than editing keys here.

Rules you must follow:

- Enabling runs a preflight check. Exit code 3 means the feature cannot work right now and the enable was **refused** (fail-closed by design). Explain the reason from stderr, point to `/media:doctor`, and do NOT retry or work around the refusal. For `display.spectrum` the usual cause is the missing audio-recording permission (grant it with audio playing).
- Disabling always succeeds.
- Afterwards show the resulting state (re-run with no arguments if helpful).
