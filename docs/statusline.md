# Now-playing in your statusline

**English** | [한국어](statusline.ko.md) | [日本語](statusline.ja.md) | [简体中文](statusline.zh-CN.md)

Show the current track as an extra line in Claude Code's statusline:

```
[your existing statusline, untouched]
▶︎ Karma Police — Radiohead  ━━━━━━────  2:13/4:24
```

The segment comes from `media.sh statusline`, which answers from a small TTL
cache (default 1s) in well under 50ms — it never slows your statusline down.
The real now-playing read runs at most once per TTL window, so the elapsed
time and progress bar advance about once a second when the statusline redraws.

## Turn it on

Inside Claude Code:

```
/media:config display.statusline on
```

That's the whole setup. Enabling verifies a working now-playing read path
first (if it is refused, run `/media:doctor`), then wires the segment into
Claude Code by itself:

1. Your current `"statusLine"` value in `~/.claude/settings.json` is backed
   up to `~/.claude/statusline-media.backup.json` (`null` when you had none).
2. A wrapper script is generated at `~/.claude/statusline-media.sh`: it runs
   your previous statusline command first and appends the now-playing line.
3. `settings.json`'s `statusLine` is pointed at the wrapper. Every other key
   of your entry (e.g. `padding`) is preserved, and `refreshInterval: 1` is
   added unless you already set one — statuslines normally refresh only on
   conversation events, and the once-a-second re-run is what makes the
   elapsed time and progress bar tick while you're idle (raise or remove it
   in `settings.json` if you prefer fewer redraws; each redraw re-runs your
   existing statusline command too).

The segment shows up on the next statusline tick — no restart, no manual
steps. Arranging the segment in `/media:statusline` enables (and wires) it
the same way.

## Design guarantees (why this is safe)

1. Your existing statusline command is **not replaced** — the wrapper runs it
   first, exactly as it was, and its output passes through **byte-for-byte
   unmodified**. Now-playing is only ever **appended as its own line**.
2. With `display.statusline` off (the default) the segment prints nothing —
   not even an empty line. Claude Code collapses the missing line, so your
   statusline looks exactly like before. (`off` hides the segment instantly
   and keeps the wiring, so re-enabling is instant too.)
3. Exactly one `settings.json` key is ever touched — `statusLine` — and only
   after its previous value is saved to `statusline-media.backup.json`. The
   write is atomic, follows symlinks (dotfile setups survive), and keeps
   every other settings key untouched.
4. **Uninstalling the plugin reverts everything by itself.** Claude Code has
   no uninstall hook a plugin could run, so the wrapper is self-healing: on
   every tick it checks the installed-plugins registry, and once the plugin
   is gone it restores your backed-up `statusLine` into `settings.json` and
   deletes itself and the backup. No leftovers — your statusline is back to
   exactly what it was, within a second of the uninstall.
5. While the plugin is merely **disabled**, the wrapper adds nothing and
   waits — your previous statusline runs as usual and the wiring stays for
   re-enabling.
6. A statusline you wired **by hand** (the recipe below, or any command that
   already runs the segment) is detected and never touched, installed or
   uninstalled.

Unwire without uninstalling the plugin — restores the backup and removes the
wrapper + backup files, and turns `display.statusline` off:

```
media.sh statusline uninstall     # or just ask Claude: "unwire the statusline"
```

`media.sh statusline status` reports the current wiring state (`managed`,
`manual`, or `none`), and `/media:doctor` includes it in its report.

## Arrange what the segment shows

Run `/media:statusline` — the one hub for the segment's look. It opens three
tabs: **Items** (volume, progress bar, time, and output device on/off),
**Layout** (Standard / Stacked, or a numeric pattern), and **Style**
(per-item styling, next section). Patterns are built from this legend:

| # | item | looks like |
| --- | --- | --- |
| 1 | `track` | `▶︎ Karma Police — Radiohead` |
| 2 | `app` | `(Spotify)` |
| 3 | `volume` | `🔉 ▄ 45%` — icon + level bar + percent; `🔇` when muted |
| 4 | `progressbar` | `━━━━━━────` |
| 5 | `time` | `2:13/4:24` |
| 6 | `output` | `🎧 AirPods Pro` — icon by device kind: `🎧` Bluetooth/headphones · `📺` HDMI/DisplayPort · `📶` AirPlay · `🔊` speakers |

Digit order is display order. `/` starts a new line. A digit you leave out
hides that item. So `123/456` puts track, app and volume on line 1 and the
rest on line 2. The default set is `track app progressbar time`; quick on/off
toggles and a full statusline reset live in `/media:config`.

How the layout behaves:

- **Order** — items render in exactly the order they are saved. Ask for
  "time first", or set the list directly:
  `/media:config statusline.fields "time,progressbar,track,app"`.
- **Explicit lines** — a `/` in the field list starts a new line. Each line
  then shows exactly the items you put there, in that order. A line with
  nothing to show disappears (e.g. `output` without the native helper).
- **Grouped layout** (no `/` in the list) — one line, or one line per group
  with `statusline.multiline on`. The groups: `app` attaches to the track;
  `progressbar` and `time` pair up when adjacent; `output` and `volume`
  join an adjacent track group, and pair up with each other when adjacent.

Standard — one line with all items (pattern `123456`):

```
▶︎ Karma Police — Radiohead (Spotify)  🔉 ▄ 45%  ━━━━━━────  2:13/4:24  🎧 AirPods Pro
```

Stacked — two explicit lines (pattern `123/456`, i.e.
`statusline.fields "track,app,volume,/,progressbar,time,output"`):

```
▶︎ Karma Police — Radiohead (Spotify)  🔉 ▄ 45%
━━━━━━────  2:13/4:24  🎧 AirPods Pro
```

Output on the track's line, no volume (pattern `126/45`):

```
▶︎ Karma Police — Radiohead (Spotify)  🎧 AirPods Pro
━━━━━━────  2:13/4:24
```

Time first, one line (pattern `5412`, i.e.
`statusline.fields "time,progressbar,track,app"`):

```
2:13/4:24  ━━━━━━────  ▶︎ Karma Police — Radiohead (Spotify)
```

The `output` and `volume` items need the native helper (they ride the same
read as the rest of the segment, so they add no extra cost). Switch devices
with `/media:output`, change the level with `/media:volume`; the segment
updates on the next tick.

### Long titles: marquee scrolling

Titles wider than 30 terminal cells scroll through a fixed 30-cell window,
one character per second. (The window advances on every redraw — see the
1-second refresh below.)

```
▶︎ ing Willow (10 Minute Version)  — Taylor Swift (Music)
```

CJK characters count as two cells, so the window stays steady for Korean,
Japanese, and Chinese titles. Prefer the full title, however long? Turn it
off:

```
/media:config statusline.marquee off
```

### Colors & per-item styles

The segment ships styled by default — Claude Code statuslines render ANSI
codes, and the wrapper passes them through untouched:

- the ▶︎/⏸ icon, the filled part of the progress bar, and the volume bar
  follow the playback state (green playing, yellow paused)
- **bold** title and elapsed time (the moving part stays readable), *italic*
  artist, dimmed total time, empty bar cells, app name, and output device

Only standard 16-color SGR codes are used, so everything follows your
terminal's own palette. Prefer plain text? Run
`/media:config statusline.color off` — the `NO_COLOR` environment variable is
honored too.

Every part is also **individually styleable** — the Style tab of
`/media:statusline`, or just tell it what you want ("title bold cyan", "bar
style dots", "volume icon ♪", "hide the artist"), or set the keys directly.
Each text key takes any of `bold dim italic underline`, plus at most one
color (`black red green yellow blue magenta cyan white` or
`bright-<color>`) — or `none` (plain), or `off` to **hide that part**:

| key | part | default |
| --- | --- | --- |
| `style.track.title` / `style.track.artist` | title / artist | `bold` / `italic` |
| `style.app` | app name `(Spotify)` | `dim` |
| `style.time.elapsed` / `style.time.total` | `2:13` / `/4:24` | `bold` / `dim` |
| `style.volume.icon` / `style.volume.style` / `style.volume.bar` / `style.volume.percent` | volume icon / bar shape / bar on-off / percent | `auto` / `block` / `on` / `dim` |
| `style.progressbar.playing` / `style.progressbar.paused` | bar fill + ▶︎/⏸ accent | `green` / `yellow` |
| `style.progressbar.style` | bar characters | `line` |
| `style.output.icon` / `style.output` | output icon / device name | `auto` / `dim` |

Hiding follows the part: a hidden title takes the `—` separator with it, a
hidden elapsed time drops the `/` before the total, and an item whose parts
are all hidden disappears entirely. (Dropping a whole item is an arrangement
change — leave its digit out of the pattern.)

The progress bar's characters come from `style.progressbar.style`:

| preset | looks like | |
|---|---|---|
| `line` (default) | `━━━━━━────` | |
| `blocks` | `██████░░░░` | |
| `smooth` | `█████▋░░░░` | the boundary cell is a partial block (⅛ steps) |
| `knob` | `━━━━━●────` | a slider head caps the fill |
| `wave` | `▂▄▆▄▂▄▁▁▁▁` | a swell — rolls while playing |
| `pulse` | `▂▂█▁▄▂▁▁▁▁` | an ECG beat — rolls while playing |
| `eq` | `▂▇▃█▅▆▁▁▁▁` | equalizer bars — rolls while playing |
| `notes` | `♪♫♪♫♪♫····` | notes — march while playing |
| `braille` | `⣿⣿⣿⣿⣿⣿⣀⣀⣀⣀` | |
| `chevron` | `▸▸▸▸▸▸▹▹▹▹` | |
| `tape` | `▰▰▰▰▰▰▱▱▱▱` | |
| `cassette` | `▮▮▮▮▮▮▯▯▯▯` | |
| `retro` | `======----` | plain ASCII |
| `dots` | `●●●●●●○○○○` | |

Any two characters also work, meaning "filled + empty" (`"#-"` →
`######----`). The rolling presets are animated: the trace rolls toward the
empty end each second while playing and freezes on pause. The same
characters draw the bar in the `/media:now` reply, so the two surfaces
always match. The volume bar's shape is
`style.volume.style`: `block` (one `▄` whose height tracks the level,
default), `progress` (a five-cell mini bar drawn with the progress-bar
characters), or `stairs` (`▂▄▆█` steps). Whatever its shape, the volume bar
draws in the progress bar's playing/paused colors — one accent across the
segment — and `style.volume.bar` is simply its on/off switch (`on` by
default). The icons (`style.volume.icon`,
`style.output.icon`) are `auto` (tiered by level / by device kind), `none`
(hidden), or any glyph like `♪` — muted always shows 🔇. Character choices
apply even with colors off; the other keys need `statusline.color` on.

```
/media:config style.track.title "bold cyan"    # set one part
/media:config style.track.title reset          # that part back to its default
/media:config style reset                      # all styles back to defaults
/media:config statusline reset                 # full stock look — arrangement,
                                               # lines, colors, marquee, styles
```

`media.sh config style` lists every key with its current value and default.
Changes show up on the next statusline tick — no restart needed.

## Manual setup (custom statuslines)

Prefer to own the wiring yourself — say, to embed the segment *inside* your
own statusline script instead of appending it as a line? Set your command up
**first**, then enable the segment: the automatic wiring recognizes a
`statusLine` command that already runs the segment (it mentions
`statusline-media.sh` or `media.sh … statusline`) and leaves it completely
alone — enabling then only flips the visibility toggle.

A universal wrapper to start from — save as `~/.claude/statusline-media.sh`
and make it executable (`chmod +x ~/.claude/statusline-media.sh`):

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

Then point `~/.claude/settings.json` at it yourself:

```json
{
  "statusLine": {
    "type": "command",
    "command": "\"$HOME/.claude/statusline-media.sh\"",
    "refreshInterval": 1
  }
}
```

(`refreshInterval: 1` keeps the time and bar ticking while you're idle — see
"Turn it on" above.) Developing from a checkout (`claude --plugin-dir`)?
Replace the `MEDIA_DIR` block with your repo path:
`np="$(/path/to/claude-media-control/scripts/media.sh statusline 2>/dev/null)"`.

## Maintenance notes

- **Managed wiring** (the automatic setup): the wrapper is a generated file —
  don't edit it; it is refreshed on plugin updates (session-start warm-up)
  and by re-running `media.sh statusline install`. `media.sh statusline
  uninstall` unwires and restores your previous statusline; uninstalling the
  plugin does the same automatically on the next statusline tick.
- **Manual wiring**: the files are yours; the plugin never touches them. If
  you change your statusline setup later, update the `EXISTING` line too. To
  undo, restore your old `"statusLine"` value in `settings.json` and delete
  your wrapper. After a plugin uninstall the segment goes quiet on its own
  (the plugin's config dies with its data directory), but the files are
  yours to remove.
- The segment honors `/media:config display.statusline off` instantly — the
  cached line is deleted on disable, no statusline restart needed.
