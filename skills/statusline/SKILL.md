---
name: statusline
description: Arrange the now-playing statusline — pick a layout preset from visual previews, or build a custom arrangement interactively: choose exactly which items appear (track, app, progress bar, time, output device), which item leads, and whether groups stack on separate lines. Use when the user wants to lay out, arrange, reorder, or redesign the statusline items, or asks what statusline layouts look like.
argument-hint: [preset | ordered item list]
allowed-tools: Bash, AskUserQuestion
---

Requested arrangement (may be empty): $ARGUMENTS

Current items, in render order:

!`"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config statusline.fields`

Current settings (see `display.statusline` and `statusline.multiline`):

!`"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config`

---

## How arrangement works

`statusline.fields` is an **ordered** list — the segment renders the items in
exactly the order they are saved. Three grouping rules: `app` attaches to the
track group when both are chosen (`▶︎ Title — Artist (App)`); `progressbar`
+ `time` share one group when adjacent; `output` joins the track group when
they sit next to each other (a folded `app` in between does not break the
adjacency). Groups matter in the stacked layout: `statusline.multiline on`
puts each group on its own line, and grouped items stay on one line.

The presets (named arrangements, usable as `$ARGUMENTS`):

| Preset | `statusline.fields` | `statusline.multiline` |
| --- | --- | --- |
| Standard | `track,app,progressbar,time` | `off` |
| Stacked | `track,app,progressbar,time` | `on` |
| Compact | `track,time` | `off` |
| Everything | `track,app,progressbar,time,output` | `off` |

## Mode A — `$ARGUMENTS` is NOT empty

Map the request onto an ordered field list + a multiline value, then save
(Step 2). A preset name maps per the table above. An explicit list
(`time,track`) passes through as-is. A described arrangement maps by intent —
e.g. "time first" → `time,progressbar,track,app`; "output device in front" →
`output,track,app,progressbar,time`; "one item per line" → keep the current
fields, `statusline.multiline on`; "track, app and output on line 1, bar and
time on line 2" → `track,app,output,progressbar,time` +
`statusline.multiline on` (the adjacent output joins the track group's line).

## Mode B — no arguments → interactive arrangement

### Call 1 — layout and lines

Ask ONE **AskUserQuestion** call with exactly TWO questions. Mark the option
matching the current state "(current)" in its label — for Q1 compare the
current item list/order, for Q2 the `statusline.multiline` value. Use exactly
these previews (they match the real renderer); if your AskUserQuestion does
not support option previews, put each sample line in the option's description
instead.

- **Q1** (single-select, header "Items"): "What should the statusline show?"

  - `Standard` — track, app, progress bar, time

    ```
    ▶︎ Karma Police — Radiohead (Spotify)  ██████░░░░  2:13/4:24
    ```

  - `Everything` — Standard plus the audio output device

    ```
    ▶︎ Karma Police — Radiohead (Spotify)  ██████░░░░  2:13/4:24  🔊 AirPods Pro
    ```

  - `Compact` — just the track and time

    ```
    ▶︎ Karma Police — Radiohead  2:13/4:24
    ```

  - `Custom…` — pick the items AND their order yourself (next step)

    ```
    e.g. time in front:
    2:13/4:24  ██████░░░░  ▶︎ Karma Police — Radiohead (Spotify)
    ```

- **Q2** (single-select, header "Lines"): "One line, or stacked?"

  - `One line` — groups side by side (`statusline.multiline off`)

    ```
    ▶︎ Karma Police — Radiohead (Spotify)  ██████░░░░  2:13/4:24
    ```

  - `Stacked` — each group on its own line (`statusline.multiline on`)

    ```
    ▶︎ Karma Police — Radiohead (Spotify)
    ██████░░░░  2:13/4:24
    ```

(The classic "Stacked" preset = `Standard` + `Stacked` lines. Q2 applies to
whatever items Q1 produces — any arrangement can stack.)

### Call 2 — ONLY when Q1 = `Custom…`

Ask a SECOND AskUserQuestion call with exactly TWO questions:

- **Q3** (`multiSelect: true`, header "Items"): "Which items besides the
  track? (the track — ▶︎ Title — Artist — is always included; to drop it,
  answer via Other)" — pre-check the items in the current list:

  - `App` — the playing app, attaches to the track: `(Spotify)`
  - `Progress bar` — `██████░░░░`
  - `Time` — elapsed/total: `2:13/4:24`
  - `Output device` — `🔊 AirPods Pro` (needs the native helper)

- **Q4** (single-select, header "Order"): "Which item leads?" — previews show
  ALL items; items not chosen in Q3 simply drop out of the final list:

  - `Track first` — the standard order → template `track,app,progressbar,time,output`

    ```
    ▶︎ Karma Police — Radiohead (Spotify)  ██████░░░░  2:13/4:24  🔊 AirPods Pro
    ```

  - `Time first` → template `time,progressbar,track,app,output`

    ```
    2:13/4:24  ██████░░░░  ▶︎ Karma Police — Radiohead (Spotify)  🔊 AirPods Pro
    ```

  - `Progress bar first` → template `progressbar,time,track,app,output`

    ```
    ██████░░░░  2:13/4:24  ▶︎ Karma Police — Radiohead (Spotify)  🔊 AirPods Pro
    ```

  - `Output first` → template `output,track,app,progressbar,time`

    ```
    🔊 AirPods Pro  ▶︎ Karma Police — Radiohead (Spotify)  ██████░░░░  2:13/4:24
    ```

Build the final field list: take the Q4 template and delete the items the
user did not choose in Q3 (keep `track` unless they excluded it via Other).
The templates keep `progressbar` and `time` adjacent on purpose — they render
as one group; only a hand-typed order via Other separates them. To keep the
output device on the track's line in the stacked layout, order it right next
to the track group (`track,app,output,progressbar,time`) — an adjacent track
+ output pair shares a group too.

In ANY question, "Other" free text is a Mode A request: map an exact list or
a described arrangement ("artist… I mean app at the very end") onto an
ordered field list, then continue with Step 2.

## Step 2 — save

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config statusline.fields "track,app,progressbar,time"
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config statusline.multiline off
```

If `display.statusline` is currently `off`, also enable it — the arrangement
is pointless without the segment:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config display.statusline on
```

If that is **refused (exit 3)**, no now-playing read path works right now;
relay the stderr reason, point to `/media:doctor`, and keep the arrangement
saved (it applies once the segment works). Never bypass the refusal.

## Step 3 — show the result

```bash
NO_COLOR=1 "${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" statusline
```

Show the output in a fenced code block (plain glyphs here; the real statusline
is ANSI-styled). If it prints nothing, say why: nothing is playing right now —
the arrangement is saved and will show once something plays.

Close with one reminder: the segment appears in Claude Code's statusline once
the one-time wrapper from `docs/statusline.md` is installed; on/off toggles,
colors, and marquee live in `/media:config`.
