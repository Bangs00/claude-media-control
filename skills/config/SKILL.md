---
name: config
description: Show or change every media display setting — statusline layout & items, progress bar, playback history, colors, marquee. Runs an interactive picker with no arguments; `config <key> [on|off]` makes a direct change. Use when the user wants to configure, customize, set up, or toggle any media display feature or the now-playing statusline.
argument-hint: [key] [on|off]
allowed-tools: Bash, AskUserQuestion
---

Requested change (may be empty): $ARGUMENTS

Current settings:

!`"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config`

Current statusline items, in render order:

!`"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config statusline.fields`

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
- `statusline.fields` — which items the statusline shows, as a comma/space list of `track app progressbar time output`; **saved in the order given, which is the render order**, and a `/` between items starts a new line (explicit per-line layout, e.g. `track,app,/,progressbar,time`; interactive picker: `/media:statusline`)

Rules you must follow:

- Enabling runs a preflight. **Exit code 3** means the feature cannot work right now and the
  enable was **refused** (fail-closed by design). Explain the reason from stderr, point to
  `/media:doctor`, and do NOT retry or work around the refusal.
- Disabling always succeeds.
- Afterwards show the resulting state (re-run `config` with no key if helpful).

## Mode B — no key given (`$ARGUMENTS` is empty) → interactive settings

Configure everything through **AskUserQuestion**. Read the "Current settings"
table and item list above first, and **pre-select the options that match the
current state** (checked = the key is `on` / the item is chosen).

### Step 1 — ask

Send these three questions together in one AskUserQuestion call:

- **Q1** header "Layout" — single-select: "How should the statusline be arranged?"
  Give each option a `preview` (samples below; if previews are unsupported,
  put the sample in the option description). Put `Keep current` first.
  - `Keep current` — no layout change; preview = the current arrangement,
    built from the current item list/order (a `/` in the list starts a new
    line; otherwise `statusline.multiline` decides) using the same sample
    track as the other previews
  - `Standard` — everything on one line — preview:
    `▶︎ Karma Police — Radiohead (Spotify)  ██████░░░░  2:13/4:24  🔊 AirPods Pro`
  - `Stacked` — three lines — preview:
    `▶︎ Karma Police — Radiohead (Spotify)` ⏎ `██████░░░░  2:13/4:24` ⏎ `🔊 AirPods Pro`
  - `Compact` — track and time only — preview:
    `▶︎ Karma Police — Radiohead  2:13/4:24`

  (Per-line custom arrangements — numeric patterns like `12/34/5` — live in
  `/media:statusline`; a wish typed via "Other" — e.g. "time first" — maps to
  an ordered field list there.)

- **Q2** header "Statusline" — `multiSelect: true`: "Statusline options? (checked = on)"
  - `Show statusline` — render the now-playing segment at all (`display.statusline`)
  - `Output device item` — append 🔊 current audio output to the items (needs the native helper)
  - `Colors` — ANSI color/bold/italic (`statusline.color`)
  - `Marquee` — scroll titles wider than 30 cells (`statusline.marquee`)

- **Q3** header "Features" — `multiSelect: true`: "Other display features? (checked = on)"
  - `Progress bar in /media:now` — the bar in the `/media:now` reply (`display.progressbar`)
  - `Playback history` — log played tracks (`history.record`, viewed with `/media:history`)

### Step 2 — save the layout (Q1 + Q2's output item)

Map the preset to an ordered field list + a multiline value — Standard =
`track,app,progressbar,time,output` + `off`, Stacked =
`track,app,/,progressbar,time,/,output` + `off` (the `/` breaks make the
lines), Compact = `track,time` + `off`. For `Keep current`, start from the
current item list and leave `statusline.multiline` alone. Then apply Q2's
`Output device item`: checked → append `output` to the list (if absent);
unchecked → drop it (a line left empty disappears on save). Save:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config statusline.fields "track,app,/,progressbar,time,/,output"
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config statusline.multiline off   # skip for Keep current
```

### Step 3 — save the toggles (Q2 + Q3)

For EACH key below, write `on` if its option was checked, `off` if not — one Bash call each:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config display.statusline on      # Q2 Show statusline
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config statusline.color on        # Q2 Colors
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config statusline.marquee on      # Q2 Marquee
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config display.progressbar on     # Q3 Progress bar in /media:now
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config history.record on          # Q3 Playback history
```

If enabling `display.statusline` is **refused (exit 3)**, no now-playing read
path works right now; relay the stderr reason and point to `/media:doctor` —
fail-closed by design, never bypass it.

### Step 4 — show the result

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config
NO_COLOR=1 "${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" statusline
```

Show the segment line in a fenced code block (plain glyphs here; the real
statusline is ANSI-styled). Remind the user the segment only appears when
`display.statusline` is on AND the wrapper from `docs/statusline.md` is
installed. (If `statusline` prints nothing, it is off or nothing is playing.)
The `NO_COLOR` env var also disables statusline color regardless of
`statusline.color`.
