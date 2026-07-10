---
name: statusline
description: Arrange the now-playing statusline — pick the Standard or Stacked preset from visual previews, or build any custom arrangement: which items appear (track, app, progress bar, time, output device), which items sit on which line, and in what order — typed compactly as a numeric pattern like 12/34/5. Use when the user wants to lay out, arrange, reorder, or redesign the statusline items or lines, or asks what statusline layouts look like.
argument-hint: [preset | pattern like 12/34/5 | ordered item list]
allowed-tools: Bash, AskUserQuestion
---

Requested arrangement (may be empty): $ARGUMENTS

Current items, in render order (`/` starts a new line):

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

**Explicit lines** — full per-line control: a `/` in the field list starts a
new line, and the whole list switches to the explicit layout. Every line then
shows exactly the items placed on it, in that order; the grouping rules and
`statusline.multiline` no longer apply. Within a line, `app` directly after
`track` still folds into it as `(App)`; anywhere else it renders as the plain
app name. A line whose items have nothing to show right now (e.g. `output`
without the native helper) disappears entirely — no blank lines.

**Numeric patterns** — wherever an arrangement can be given ($ARGUMENTS, an
"Other" answer), digits name the items, `/` starts a new line, digit order =
display order, and digits left out are omitted:

| digit | item | looks like |
| --- | --- | --- |
| 1 | `track` | `▶︎ Karma Police — Radiohead` |
| 2 | `app` | `(Spotify)` |
| 3 | `progressbar` | `██████░░░░` |
| 4 | `time` | `2:13/4:24` |
| 5 | `output` | `🔊 AirPods Pro` |

`12/34/5` → `track,app,/,progressbar,time,/,output` (three lines);
`43/125` → `time,progressbar,/,track,app,output`; `14` → `track,time`.

The presets (named arrangements, usable as `$ARGUMENTS`):

| Preset | `statusline.fields` | `statusline.multiline` |
| --- | --- | --- |
| Standard | `track,app,progressbar,time,output` | `off` |
| Stacked | `track,app,/,progressbar,time,/,output` | `off` (the `/` breaks make the lines) |
| Compact | `track,time` | `off` |

(`Everything` is a legacy alias — accept it, save Standard.)

## Mode A — `$ARGUMENTS` is NOT empty

Map the request onto an ordered field list, then save (Step 2). A preset name
maps per the table above. A numeric pattern maps per the digit legend. An
explicit list (`time,track` or `track,app,/,progressbar,time`) passes through
as-is. A described arrangement maps by intent — e.g. "time first" →
`time,progressbar,track,app`; "track, app and output on line 1, bar and time
on line 2" → `track,app,output,/,progressbar,time`; "3 lines: track / bar and
time / output" → `track,app,/,progressbar,time,/,output`; "time alone on
top" → `time,/,track,app,progressbar`. Order within a line is the order
within its `/` span.

## Mode B — no arguments → interactive arrangement

### Call 1 — layout

Ask ONE **AskUserQuestion** call with exactly ONE question (single-select,
header "Layout"): "How should the statusline look?" Mark the option matching
the current state "(current)" in its label — compare the current field list
against the preset rows. Use exactly these previews (they match the real
renderer); if your AskUserQuestion does not support option previews, put the
sample lines in the option descriptions instead.

- `Standard` — everything on one line

  ```
  ▶︎ Karma Police — Radiohead (Spotify)  ██████░░░░  2:13/4:24  🔊 AirPods Pro
  ```

- `Stacked` — three lines: track / progress / output

  ```
  ▶︎ Karma Police — Radiohead (Spotify)
  ██████░░░░  2:13/4:24
  🔊 AirPods Pro
  ```

- `Custom…` — put any items on any lines, in any order (next step)

  ```
  1 track · 2 app · 3 bar · 4 time · 5 output
  e.g. 12/34/5 → track+app / bar+time / output
  ```

### Call 2 — ONLY when Call 1 = `Custom…`

Ask ONE question (single-select, header "Lines") whose text carries the item
legend and the input syntax, e.g.:

> Which items go on which lines? Pick a pattern, or type your own via Other —
> 1 track, 2 app, 3 progress bar, 4 time, 5 output; `/` starts a new line;
> digit order = display order; leave a digit out to hide that item
> (e.g. `12/34/5`, `43/125`, `14`).

Options — the label IS the pattern; previews show all five items:

- `125/34` — track, app & output on top, progress & time below

  ```
  ▶︎ Karma Police — Radiohead (Spotify)  🔊 AirPods Pro
  ██████░░░░  2:13/4:24
  ```

- `12/345` — track & app on top, stats with output below

  ```
  ▶︎ Karma Police — Radiohead (Spotify)
  ██████░░░░  2:13/4:24  🔊 AirPods Pro
  ```

- `43/125` — time & bar on top, track below

  ```
  2:13/4:24  ██████░░░░
  ▶︎ Karma Police — Radiohead (Spotify)  🔊 AirPods Pro
  ```

- `1/2/3/4/5` — one item per line

  ```
  ▶︎ Karma Police — Radiohead
  Spotify
  ██████░░░░
  2:13/4:24
  🔊 AirPods Pro
  ```

  (an `app` on its own line renders as the plain app name — parens only when
  it sits right after the track)

An "Other" answer that is a numeric pattern maps per the legend; anything
else (an item list, "time first") is a Mode A request — map it, then continue
with Step 2.

## Step 2 — save

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config statusline.fields "track,app,/,progressbar,time,/,output"
```

When the list contains `/`, leave `statusline.multiline` alone — explicit
lines ignore it. When it does NOT (a one-line arrangement), also write

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config statusline.multiline off
```

so a leftover stacked flag cannot re-split the new arrangement.

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
