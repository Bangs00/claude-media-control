---
name: config
description: Show or change every media display setting — statusline items & layout, progress bar, audio spectrum, playback history, colors, marquee, spectrum color. Runs an interactive picker with no arguments; `config <key> [on|off]` makes a direct change. Use when the user wants to configure, customize, set up, lay out, or toggle any media display feature or the now-playing statusline.
argument-hint: [key] [on|off]
allowed-tools: Bash, AskUserQuestion
---

Requested change (may be empty): $ARGUMENTS

Current settings:

!`"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config`

Current statusline items:

!`"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config statusline.fields`

---

Pick the mode from `$ARGUMENTS`:

## Mode A — a key was given (`$ARGUMENTS` is NOT empty)

The user named a specific key (e.g. `display.spectrum on`, `spectrum.color magenta`,
`statusline.marquee off`). Apply it directly and report the result:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config $ARGUMENTS
```

Valid keys:

- `display.progressbar` — progress bar in the `/media:now` reply
- `display.statusline` — the statusline now-playing segment
- `display.spectrum` — the audio spectrum (opt-in; enabling needs the system-audio-recording permission)
- `statusline.multiline` — layout: `on` = each group on its own line, `off` = one line
- `statusline.color` — ANSI colors/bold/italic in the statusline (default `on`; the `NO_COLOR` env var also disables it)
- `statusline.marquee` — scroll statusline titles wider than 30 cells, one char/second (default `on`)
- `history.record` — log played tracks to the local history (default `on`; view with `/media:history`)
- `statusline.fields` — which items the statusline shows; a comma/space list of `track app progressbar time output spectrum`
- `spectrum.style` — spectrum coloring: `solid` (default) or `rainbow` (fixed front-to-back cycle by bar position)
- `spectrum.color` — the solid spectrum color: `red green yellow blue magenta cyan white` (default `cyan`; ignored when style is `rainbow`)

Rules you must follow:

- Enabling runs a preflight. **Exit code 3** means the feature cannot work right now and the
  enable was **refused** (fail-closed by design). Explain the reason from stderr, point to
  `/media:doctor`, and do NOT retry or work around the refusal. For `display.spectrum` the usual
  cause is the missing system-audio-recording permission (grant it with audio playing).
- Disabling always succeeds.
- If the user asks for a rainbow/unicorn spectrum → `spectrum.style rainbow`; a specific color
  ("make the spectrum magenta") → `spectrum.color magenta` (plus `spectrum.style solid` if it was rainbow).
- Afterwards show the resulting state (re-run `config` with no key if helpful).

## Mode B — no key given (`$ARGUMENTS` is empty) → interactive settings

Configure everything through **AskUserQuestion**. Read the "Current settings" table and item
list above first, and **pre-select the options that match the current state** (checked = the key
is `on` / the item is chosen).

### Step 1 — ask

Send these questions together (if your AskUserQuestion can't take four at once, send Q1–Q3
first, then Q4). Every question is `multiSelect: true` — checked means on/shown.

- **Q1** header "Items" — "Which now-playing items should the statusline show?"
  - `Track` — ▶︎ title — artist
  - `App` — the playing app, e.g. (Spotify)
  - `Progress bar` — ██████░░░░ in the statusline
  - `Time` — elapsed / total

- **Q2** header "Extras" — "Any extra statusline items?"
  - `Output device` — 🔊 current audio output (needs the native helper)
  - `Spectrum` — live frequency bars (opt-in; needs the audio-recording permission)
  - `None` — track info only

- **Q3** header "Statusline" — "Statusline display options? (checked = on)"
  - `Show statusline` — render the now-playing segment at all (`display.statusline`)
  - `Separate lines` — each group on its own line (`statusline.multiline`)
  - `Colors` — ANSI color/bold/italic (`statusline.color`)
  - `Marquee` — scroll titles wider than 30 cells (`statusline.marquee`)

- **Q4** header "Features" — "Other display features? (checked = on)"
  - `Progress bar in /media:now` — the bar in the `/media:now` reply (`display.progressbar`)
  - `Playback history` — log played tracks (`history.record`, viewed with `/media:history`)

### Step 2 — save the statusline items (Q1 + Q2)

Map the chosen items to field names (Track→`track`, App→`app`, Progress bar→`progressbar`,
Time→`time`, Output device→`output`, Spectrum→`spectrum`) and save them, dropping `None`
(comma-separated; order does not matter, the script canonicalizes):

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config statusline.fields "track,app,progressbar,time,output,spectrum"
```

### Step 3 — save the toggles (Q3 + Q4)

For EACH key below, write `on` if its option was checked, `off` if not — one Bash call each:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config display.statusline on      # Q3 Show statusline
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config statusline.multiline on     # Q3 Separate lines
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config statusline.color on         # Q3 Colors
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config statusline.marquee on       # Q3 Marquee
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config display.progressbar on      # Q4 Progress bar in /media:now
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config history.record on           # Q4 Playback history
```

### Step 4 — spectrum (only if `Spectrum` was chosen in Q2)

Enable it (it is off by default):

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config display.spectrum on
```

If this is **refused (exit 3)**, the system-audio-recording permission is missing. Tell the user
to grant it to their terminal app (System Settings > Privacy & Security, with audio playing),
then re-save `statusline.fields` **without** `spectrum` so the rest works. Do not force it.

If it enabled, ask ONE more **AskUserQuestion** (single-select, header "Spectrum") — "How should
the spectrum bars be colored?":

- `Solid cyan (default)` — one color, the default
- `Solid — another color` — then take the color (red/green/yellow/blue/magenta/white) via the Other field or a follow-up
- `Rainbow` — front-to-back color cycle (ignores the solid color)

Save with:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config spectrum.style solid       # or rainbow
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config spectrum.color magenta     # only for a custom solid
```

If `Spectrum` was **not** chosen, turn it off so the capture and field stop:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config display.spectrum off
```

### Step 5 — show the result

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" statusline
```

Remind the user the statusline segment only appears when `display.statusline` is on AND the
wrapper from `docs/statusline.md` is installed. (If `statusline` prints nothing, it is off or
nothing is playing.) The `NO_COLOR` env var also disables statusline color regardless of
`statusline.color`, and the `display.spectrum` refusal is fail-closed by design — never bypass it.
