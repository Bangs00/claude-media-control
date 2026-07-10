---
name: config
description: Quick media settings — turn the now-playing statusline, the /media:now progress bar, or the playback history on/off, or reset the statusline to its default look. `config <key> [on|off|value]` changes any key directly. Use when the user wants to enable, disable, or reset a media display feature. (Arranging and styling the statusline lives in /media:statusline.)
argument-hint: [key] [on|off]
allowed-tools: Bash, AskUserQuestion
---

Requested change (may be empty): $ARGUMENTS

Current settings:

!`"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config`

---

Pick the mode from `$ARGUMENTS`:

## Mode A — a key was given (`$ARGUMENTS` is NOT empty)

The user named a specific key (e.g. `display.statusline on`,
`statusline.marquee off`). Apply it directly and report the result:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config $ARGUMENTS
```

Valid keys:

- `display.progressbar` — progress bar in the `/media:now` reply
- `display.statusline` — the statusline now-playing segment
- `statusline.multiline` — layout: `on` = each group on its own line, `off` = one line (unused when `statusline.fields` has `/` breaks)
- `statusline.color` — ANSI colors/bold/italic in the statusline (default `on`; the `NO_COLOR` env var also disables it)
- `statusline.marquee` — scroll statusline titles wider than 30 cells, one char/second (default `on`)
- `history.record` — log played tracks to the local history (default `on`; view with `/media:history`)
- `statusline.fields` — which items the statusline shows, as an ordered comma/space list of `track app volume progressbar time output` with optional `/` line breaks (interactive: `/media:statusline`)
- `style.<part>` — per-item statusline styles (14 string-valued keys; `config style` lists them, the value `reset` restores one, `config style reset` restores all). Guided styling lives in `/media:statusline`.
- `statusline reset` — restore the whole statusline **appearance** to defaults: arrangement, explicit lines, colors, marquee, and every `style.*` key. Does not touch `display.statusline` or the non-statusline toggles.

Rules you must follow:

- Enabling runs a preflight. **Exit code 3** means the feature cannot work right now and the
  enable was **refused** (fail-closed by design). Explain the reason from stderr, point to
  `/media:doctor`, and do NOT retry or work around the refusal.
- Disabling always succeeds.
- Afterwards show the resulting state (re-run `config` with no key if helpful).

## Mode B — no key given (`$ARGUMENTS` is empty) → quick settings

Ask ONE **AskUserQuestion** call with exactly ONE question (single-select,
header "Settings"): "Which setting do you want to change?" — exactly these
four options, with the CURRENT value from the settings table above baked into
each label so the user sees the state before picking:

1. `Statusline: <on|off>` — description: the now-playing segment rendered
   into Claude Code's statusline (needs the one-time wrapper from
   `docs/statusline.md`); selecting flips it.
2. `/media:now progress bar: <on|off>` — description: the progress bar drawn
   under the `/media:now` reply; selecting flips it.
3. `Playback history: <on|off>` — description: passively log played tracks
   (view with `/media:history`); selecting flips it.
4. `Reset statusline settings` — description: restore the statusline's
   default look — arrangement, lines, colors, marquee, and all per-item
   styles. The three toggles above are not touched.

Then apply the selection with one Bash call:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config display.statusline on   # option 1 (flip)
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config display.progressbar on  # option 2 (flip)
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config history.record on       # option 3 (flip)
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config statusline reset        # option 4
```

If enabling `display.statusline` is **refused (exit 3)**, no now-playing read
path works right now; relay the stderr reason and point to `/media:doctor` —
fail-closed by design, never bypass it. An "Other" answer names a key or a
wish — map it onto Mode A (arrangement or styling wishes belong to
`/media:statusline`; run that flow instead of guessing keys here).

### Show the result

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config
```

Report the changed key (old → new) in one line. After a reset, mention the
statusline is back to its stock look. Close with one pointer: arranging items
and lines, and styling any part (colors, bold/italic, bar characters, icons)
live in `/media:statusline`.
