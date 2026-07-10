---
name: statusline
description: Arrange the now-playing statusline — pick a layout preset from visual previews, or set exactly which items appear and in what order (track, app, progress bar, time, output device) and whether they stack on separate lines. Use when the user wants to lay out, arrange, reorder, or redesign the statusline items, or asks what statusline layouts look like.
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
exactly the order they are saved. Two grouping rules: `app` attaches to the
track group when both are chosen (`▶︎ Title — Artist (App)`), and `progressbar`
+ `time` share one group when adjacent (they stay on one line in the stacked
layout). `statusline.multiline on` puts each group on its own line.

The presets:

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
fields, `statusline.multiline on`.

## Mode B — no arguments → show the layouts

Ask ONE **AskUserQuestion** (single-select, header "Layout"): "How should the
now-playing statusline be arranged?" — with one option per preset, each
carrying a `preview` so the user can see the arrangement before choosing.
Mark the option matching the current state "(current)". Use exactly these
previews (they match the real renderer):

- `Standard` — one line: track, app, progress bar, time

  ```
  ▶︎ Karma Police — Radiohead (Spotify)  ██████░░░░  2:13/4:24
  ```

- `Stacked` — same items, one group per line

  ```
  ▶︎ Karma Police — Radiohead (Spotify)
  ██████░░░░  2:13/4:24
  ```

- `Compact` — just the track and time

  ```
  ▶︎ Karma Police — Radiohead  2:13/4:24
  ```

- `Everything` — Standard plus the audio output device

  ```
  ▶︎ Karma Police — Radiohead (Spotify)  ██████░░░░  2:13/4:24  🔊 AirPods Pro
  ```

If the user picks "Other" and types a wish, treat it as Mode A input. If your
AskUserQuestion does not support option previews, put each sample line in the
option's description instead.

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
