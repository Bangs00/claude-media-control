---
name: statusline
description: Arrange the now-playing statusline — pick the Standard or Stacked preset from visual previews, or build any custom arrangement: which items appear (track, app, volume, progress bar, time, output device), which items sit on which line, and in what order — typed compactly as a numeric pattern like 123/456. Use when the user wants to lay out, arrange, reorder, or redesign the statusline items or lines, or asks what statusline layouts look like.
argument-hint: [preset | pattern like 123/456 | ordered item list]
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
exactly the order they are saved. Grouping rules: `app` attaches to the track
group when both are chosen (`▶︎ Title — Artist (App)`); `progressbar` + `time`
share one group when adjacent; `output` and `volume` join the track group
when they sit next to it, and adjacent `output`+`volume` share one group (a
folded `app` in between does not break the adjacency). Groups matter in the
stacked layout: `statusline.multiline on` puts each group on its own line,
and grouped items stay on one line.

**Explicit lines** — full per-line control: a `/` in the field list starts a
new line, and the whole list switches to the explicit layout. Every line then
shows exactly the items placed on it, in that order; the grouping rules and
`statusline.multiline` no longer apply. Within a line, `app` directly after
`track` still folds into it as `(App)`; anywhere else it renders as the plain
app name. A line whose items have nothing to show right now (e.g. `output` or
`volume` without the native helper) disappears entirely — no blank lines.

**Numeric patterns** — wherever an arrangement can be given ($ARGUMENTS, a
typed reply, an "Other" answer), digits name the items, `/` starts a new
line, digit order = display order, and digits left out are omitted. The digit
order is also the default item order:

| digit | item | looks like |
| --- | --- | --- |
| 1 | `track` | `▶︎ Karma Police — Radiohead` |
| 2 | `app` | `(Spotify)` |
| 3 | `volume` | `🔉 ▄ 45%` (🔇 when muted) |
| 4 | `progressbar` | `━━━━━━────` |
| 5 | `time` | `2:13/4:24` |
| 6 | `output` | `🎧 AirPods Pro` (icon by device: 🔊 speakers · 🎧 Bluetooth/headphones · 📺 HDMI/DisplayPort · 📶 AirPlay) |

`123/456` → `track,app,volume,/,progressbar,time,output` (two lines);
`45/126` → `progressbar,time,/,track,app,output`; `15` → `track,time`.

The presets (named arrangements, usable as `$ARGUMENTS`):

| Preset | `statusline.fields` | `statusline.multiline` |
| --- | --- | --- |
| Standard | `track,app,volume,progressbar,time,output` | `off` |
| Stacked | `track,app,volume,/,progressbar,time,output` | `off` (the `/` break makes the lines) |
| Compact | `track,time` | `off` |

(`Everything` is a legacy alias — accept it, save Standard.)

## Mode A — `$ARGUMENTS` is NOT empty

Map the request onto an ordered field list, then save (Step 2). A preset name
maps per the table above. A numeric pattern maps per the digit legend. An
explicit list (`time,track` or `track,app,/,progressbar,time`) passes through
as-is. A described arrangement maps by intent — e.g. "time first" →
`time,progressbar,track,app`; "track, app and volume on line 1, the rest on
line 2" → `track,app,volume,/,progressbar,time,output`; "3 lines: track /
bar and time / output" → `track,app,/,progressbar,time,/,output`; "time
alone on top" → `time,/,track,app,progressbar`. Order within a line is the
order within its `/` span.

## Mode B — no arguments → interactive arrangement

### Call 1 — layout

Ask ONE **AskUserQuestion** call with exactly ONE question (single-select,
header "Layout"): "How should the statusline look? (`Custom…` lets you type a
numeric pattern; typing one via Other works right away too)". Mark the option
matching the current state "(current)" in its label — compare the current
field list against the preset rows. Use exactly these previews (they match
the real renderer); if your AskUserQuestion does not support option previews,
put the sample lines in the option descriptions instead.

- `Standard` — everything on one line

  ```
  ▶︎ Karma Police — Radiohead (Spotify)  🔉 ▄ 45%  ━━━━━━────  2:13/4:24  🎧 AirPods Pro
  ```

- `Stacked` — two lines: track, app & volume / stats & output

  ```
  ▶︎ Karma Police — Radiohead (Spotify)  🔉 ▄ 45%
  ━━━━━━────  2:13/4:24  🎧 AirPods Pro
  ```

- `Custom…` — type which items go on which lines as a numeric pattern

  ```
  1 track · 2 app · 3 volume · 4 bar · 5 time · 6 output
  next: type a pattern like 123/456 into the chat
  ```

An "Other" answer here is already the arrangement — map it (a numeric pattern
per the legend, anything else per Mode A) and continue with Step 2.

### Call 2 — ONLY when Call 1 = `Custom…` → direct pattern input

Do NOT ask another AskUserQuestion — the pattern is typed straight into the
normal chat input, where digits and `/` need no option-navigation. End your
reply with the digit legend and the syntax, then stop and wait for the user's
next message. Reply with exactly this shape (translate prose to the
conversation language, keep the table):

> Type your pattern: each digit is an item, digit order = display order, `/`
> starts a new line, and a digit you leave out hides that item.
> Current: `123/456`
>
> | # | item | looks like |
> | --- | --- | --- |
> | 1 | track | ▶︎ Karma Police — Radiohead |
> | 2 | app | (Spotify) |
> | 3 | volume | 🔉 ▄ 45% |
> | 4 | progress bar | ━━━━━━──── |
> | 5 | time | 2:13/4:24 |
> | 6 | output | 🎧 AirPods Pro |
>
> e.g. `123456` = one line · `123/456` = two lines · `1/45` = track on top,
> bar & time below

For `Current:` convert the current field list to digits (`/` stays `/`, e.g.
`track app / time` → `1/5`). Map the reply: a numeric pattern per the legend;
an item list or described arrangement per Mode A; if it maps to nothing,
restate the legend line briefly and ask again. Then continue with Step 2.

## Step 2 — save

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config statusline.fields "track,app,volume,/,progressbar,time,output"
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
colors, and marquee live in `/media:config`, and per-item styles (bold /
italic / color per part, progress-bar characters, the volume icon) in
`/media:style`.
