# Now-playing in your statusline

**English** | [한국어](statusline.ko.md) | [日本語](statusline.ja.md) | [简体中文](statusline.zh-CN.md)

The current track, as an extra line in Claude Code's statusline:

```
[your existing statusline, untouched]
▶︎ Karma Police — Radiohead (Spotify)  ━━━━━━━━━━━━────────  2:13/4:24
```

The segment answers from a 1-second TTL cache in well under 50ms — it never
slows your statusline down. The real now-playing read runs at most once per
second, which is also what makes the time and bar tick.

## Turn it on

```
/media:config display.statusline on
```

That's the whole setup — no restart, no manual steps. (Arranging the segment
in `/media:statusline` enables it the same way.) Enabling first verifies a
working now-playing read path (refused? run `/media:doctor`), then wires the
segment in by itself:

1. Your current `"statusLine"` value in `~/.claude/settings.json` is backed
   up to `~/.claude/statusline-media.backup.json` (`null` if you had none).
2. A wrapper is generated at `~/.claude/statusline-media.sh`: it runs your
   previous statusline command first, then appends the now-playing line.
3. `settings.json` points at the wrapper. Every other key of your entry
   (e.g. `padding`) is preserved, and `refreshInterval: 1` is added unless
   you set one — that once-a-second re-run is what keeps the time and bar
   moving while you're idle. (Raise or remove it for fewer redraws; each
   redraw re-runs your existing statusline command too.)

## Click to control

In terminals with hyperlink support, the segment is **cmd+clickable**:

| Target | ⌘+click does |
| --- | --- |
| `▶︎` / `⏸` icon | toggle play/pause |
| title — artist, `(App)` | jump to the playing media: the playing browser tab (Safari, Chrome, Edge, Brave, Vivaldi, Opera) or the current track in Music; other apps just come to the front |
| progress bar | seek — every cell jumps to its position (at the default 20 cells: 2.5%, 7.5%, … 97.5%; a longer bar seeks in finer steps) |

- **Works in**: iTerm2, Ghostty, WezTerm, Kitty, VS Code, Alacritty ≥ 0.11
  (tmux ≥ 3.4 passes links through). Terminals without hyperlink support
  just show the plain segment.
- The segment reflects a click on the next tick (≤ 1s): the icon flips, the
  bar jumps.
- Switch: `/media:config statusline.links off` renders the segment plain.
  Turning it back on rebuilds the handler app, and is refused (exit 3) if
  that build fails — a link nothing answers is worse than no link.
- The first tab-jump asks once for Automation consent
  (`ClaudeMediaClick.app`); denying keeps plain activation, silently.

<details>
<summary>How clicks work (and why they're safe)</summary>

The clickable parts are OSC 8 hyperlinks pointing at a local
`claude-media://` URL scheme. Enabling the statusline builds a tiny handler
app (`ClaudeMediaClick.app`, generated into the plugin data directory with
macOS's bundled `osacompile` — no third-party code) and registers it with
LaunchServices. A click runs `media.sh open-url`, whose whole surface is
exactly three benign actions — toggle, activate, seek by percent; anything
else is rejected. A URL scheme is reachable by any app by nature, so that
surface is the point: play/pause, bringing the player forward, seeking —
nuisance-level at worst, the same class as your keyboard's media keys.

For browser players, activation resolves the web-content helper process to
its owning app (e.g. `com.openai.atlas.web` → ChatGPT Atlas), then lands on
the media itself where the app is scriptable: the window+tab whose title
matches the track, or Music's current track. Apps without a scripting
interface (e.g. ChatGPT Atlas, Spotify) stop at coming to the front.
Uninstalling the plugin (or `media.sh statusline uninstall`) unregisters
and deletes the handler app. `/media:doctor` reports its state
(`Click links`).

</details>

## Arrange what the segment shows

`/media:statusline` is the hub for the segment's look — three tabs: **Items**
(on/off), **Layout** (presets or a numeric pattern), **Style** (see the
[style gallery](styles.md)). Patterns use this legend:

| # | Item | Looks like |
| --- | --- | --- |
| 1 | `track` | `▶︎ Karma Police — Radiohead` |
| 2 | `app` | `(Spotify)` |
| 3 | `volume` | `🔉 ▄ 45%` — `🔇` when muted |
| 4 | `progressbar` | `━━━━━━━━━━━━────────` |
| 5 | `time` | `2:13/4:24` |
| 6 | `output` | `🎧 AirPods Pro` — icon by device kind |

Digit order is display order, `/` starts a new line, and a digit you leave
out hides that item. The default set is `track app progressbar time`; the
list can also be set directly:
`/media:config statusline.fields "time,progressbar,track,app"`.

Standard — everything on one line (`123456`):

```
▶︎ Karma Police — Radiohead (Spotify)  🔉 ▄ 45%  ━━━━━━━━━━━━────────  2:13/4:24  🎧 AirPods Pro
```

Stacked — two lines (`123/456`):

```
▶︎ Karma Police — Radiohead (Spotify)  🔉 ▄ 45%
━━━━━━━━━━━━────────  2:13/4:24  🎧 AirPods Pro
```

Output next to the track, no volume (`126/45`):

```
▶︎ Karma Police — Radiohead (Spotify)  🎧 AirPods Pro
━━━━━━━━━━━━────────  2:13/4:24
```

How the layout behaves:

- **With `/` in the list** (explicit layout): each line shows exactly the
  items you put there, in that order. A line with nothing to show
  disappears entirely — no blank lines.
- **Without `/`** (grouped layout): one line — or one line per group with
  `statusline.multiline on`. The groups: `app` attaches to the track,
  adjacent `progressbar`+`time` pair up, `output`/`volume` join an adjacent
  track group (and pair with each other).
- `output` and `volume` need the native helper; they ride the same read as
  the rest, so they add no extra cost.

## Styling

The segment ships styled: green/yellow accent by playback state, **bold**
title and elapsed time, *italic* artist, dim chrome — standard 16-color SGR,
so your terminal's palette decides the shades.

Every part is individually styleable — colors (names or hex codes like
`#ff8800`), bold/italic, 22 progress-bar charsets, the bar length (1–60
cells, default 20), volume bar shapes, icons,
or `off` to hide any part. **The full catalog, with examples and recipes:
[docs/styles.md](styles.md).**

```
/media:config statusline.color off     # plain text (NO_COLOR works too)
/media:config statusline.marquee off   # don't scroll long titles
```

Titles wider than 30 cells scroll marquee-style through a fixed window, one
character per second (CJK counts as two cells, so the window stays steady).

## All toggles at a glance

| Key (`/media:config …`) | Default | Does |
| --- | --- | --- |
| `display.statusline` | `off` | show the segment (enabling wires it in) |
| `statusline.fields` | `track,app,progressbar,time` | items, order, and `/` line breaks |
| `statusline.multiline` | `off` | grouped layout: one line per group |
| `statusline.color` | `on` | ANSI styling (`NO_COLOR` wins) |
| `statusline.marquee` | `on` | scroll titles wider than 30 cells |
| `statusline.links` | `on` | cmd+click actions |
| `statusline reset` | — | restore the stock look (arrangement, lines, colors, marquee, styles) |

## Manual setup (custom statuslines)

Prefer to own the wiring — say, to embed the segment *inside* your own
statusline script? Set your command up **first**, then enable: the automatic
wiring recognizes a `statusLine` that already runs the segment (it mentions
`statusline-media.sh` or `media.sh … statusline`) and leaves it alone;
enabling then only flips the visibility toggle.

A universal wrapper to start from — save as `~/.claude/statusline-media.sh`,
`chmod +x` it:

```bash
#!/bin/bash
# statusline-media.sh — existing statusline (verbatim) + now-playing line.
input=$(cat)

# ── 1. Your existing statusLine command, pasted verbatim between the quotes.
#       Take it from the "command" value under "statusLine" in settings.json.
#       Leave EXISTING empty if you had no statusline before.
EXISTING=''
if [ -n "$EXISTING" ]; then
  printf '%s' "$input" | bash -c "$EXISTING"
fi

# ── 2. Now-playing (empty when off / nothing playing / plugin missing).
#       Resolves the newest installed plugin version at run time, so the
#       wrapper survives plugin updates.
MEDIA_DIR="$(ls -d "$HOME"/.claude/plugins/cache/claude-media-control/media/*/ 2>/dev/null \
  | awk -F/ '{ print $(NF-1) "\t" $0 }' \
  | sort -t. -k1,1n -k2,2n -k3,3n \
  | tail -1 | cut -f2-)"
if [ -n "$MEDIA_DIR" ] && [ -x "${MEDIA_DIR}scripts/media.sh" ]; then
  np="$("${MEDIA_DIR}scripts/media.sh" statusline 2>/dev/null)"
  [ -n "$np" ] && printf '%s\n' "$np"
fi
exit 0
```

Then point `~/.claude/settings.json` at it:

```json
{
  "statusLine": {
    "type": "command",
    "command": "\"$HOME/.claude/statusline-media.sh\"",
    "refreshInterval": 1
  }
}
```

Developing from a checkout (`claude --plugin-dir`)? Replace the `MEDIA_DIR`
block with your repo path:
`np="$(/path/to/claude-media-control/scripts/media.sh statusline 2>/dev/null)"`.

## Design guarantees (why this is safe)

1. Your existing statusline is **never replaced** — the wrapper runs it
   first and its output passes through byte-for-byte; now-playing is only
   ever appended as its own line.
2. Off (the default) prints nothing — not even an empty line. Claude Code
   collapses the missing line, so your statusline looks exactly as before.
3. Exactly one `settings.json` key is ever touched — `statusLine` — and only
   after its previous value is backed up. The write is atomic, follows
   symlinks (dotfile setups survive), and keeps every other key untouched.
4. **Uninstalling the plugin reverts everything by itself.** Claude Code has
   no uninstall hook, so the wrapper self-heals: once the plugin is gone it
   restores your backed-up `statusLine`, deletes itself and the backup, and
   removes the click-handler app — within a second of the uninstall.
5. While the plugin is merely **disabled**, the wrapper adds nothing and
   waits; your previous statusline runs as usual.
6. A statusline you wired **by hand** is detected and never touched —
   installed or uninstalled.

## Wiring commands

```
media.sh statusline status      # managed | manual | none (also in /media:doctor)
media.sh statusline uninstall   # unwire without uninstalling the plugin:
                                # restores the backup, removes wrapper + backup,
                                # turns display.statusline off
```

Notes:

- **Managed wiring**: the wrapper is a generated file — don't edit it; it's
  refreshed on plugin updates and by re-running `media.sh statusline install`.
- **Manual wiring**: the files are yours; the plugin never touches them. If
  you change your statusline later, update the `EXISTING` line too. After a
  plugin uninstall the segment goes quiet on its own, but remove your
  wrapper and restore your `"statusLine"` yourself.
- `/media:config display.statusline off` takes effect instantly — the cached
  line is deleted on disable; re-enabling is instant too (the wiring stays).
