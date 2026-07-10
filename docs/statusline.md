# Now-playing in your statusline

**English** | [한국어](statusline.ko.md) | [日本語](statusline.ja.md) | [简体中文](statusline.zh-CN.md)

Show the current track as an extra line in Claude Code's statusline:

```
[your existing statusline, untouched]
▶︎ Karma Police — Radiohead  ██████░░░░  2:13/4:24
```

The segment comes from `media.sh statusline`, which answers from a small TTL
cache (default 1s) in well under 50ms — it never slows your statusline down.
The real now-playing read runs at most once per TTL window, so the elapsed
time and progress bar advance about once a second when the statusline redraws.

## Design guarantees (why this is safe to add)

1. Your existing statusline command is **not replaced** — the wrapper runs it
   first, exactly as it was.
2. Its output passes through **byte-for-byte unmodified**.
3. Now-playing is only ever **appended as its own line**.
4. With `display.statusline` off (the default) the segment command prints
   nothing — not even an empty line. Claude Code collapses the missing line,
   so your statusline looks exactly like before.

The plugin never edits `settings.json` for you; everything below is a manual,
reversible edit.

## Step 1 — enable the segment

Inside Claude Code:

```
/media:config display.statusline on
```

(Enabling verifies a working now-playing read path first; if it is refused,
run `/media:doctor`.)

### Arrange what the segment shows

Run `/media:statusline` to arrange the segment — the picker shows preset
layouts (Standard / Everything / Compact) as visual previews, asks whether
groups share one line or stack, and `Custom…` walks you through building
your own arrangement: pick exactly which items appear, then which item
leads. A quick preset picker also opens inside `/media:config`:

- **Items** (any combination, **in any order**): `track` (▶︎ title — artist),
  `app` (the playing app, e.g. `(Spotify)`), `progressbar` (`██████░░░░`),
  `time` (`2:13/4:24`), `output` (🔊 current audio output device). The default
  set is `track app progressbar time`.
- **Order**: items render in exactly the order they are saved — ask for "time
  first" or "output device in front", or set it directly:
  `/media:config statusline.fields "time,progressbar,track,app"`.
- **Layout**: one line, or each group on its own line (`statusline.multiline`).
  `app` attaches to the track group; `progressbar` and `time` share a group
  when they sit next to each other in the order, and so do the track and
  `output` — put the output device right after the track to keep it on the
  track's line when stacked.

One line with all items:

```
▶︎ Karma Police — Radiohead (Spotify)  ██████░░░░  2:13/4:24  🔊 AirPods Pro
```

Stacked (`statusline.multiline on`):

```
▶︎ Karma Police — Radiohead (Spotify)
██████░░░░  2:13/4:24
🔊 AirPods Pro
```

Stacked, output on the track line
(`statusline.fields "track,app,output,progressbar,time"`):

```
▶︎ Karma Police — Radiohead (Spotify)  🔊 AirPods Pro
██████░░░░  2:13/4:24
```

Time first (`statusline.fields "time,progressbar,track,app"`):

```
2:13/4:24  ██████░░░░  ▶︎ Karma Police — Radiohead (Spotify)
```

The `output` item needs the native helper (it rides the same read as the rest
of the segment, so it adds no extra cost). Switch devices with
`/media:output`; the segment updates on the next tick.

### Long titles: marquee scrolling

Titles wider than 30 terminal cells scroll through a fixed 30-cell window, one
character per second (this pairs with the 1-second refresh below — the window
advances on every redraw):

```
▶︎ ing Willow (10 Minute Version)  — Taylor Swift (Music)
```

CJK characters count as two cells, so the window stays steady for Korean,
Japanese, and Chinese titles. Prefer the full title, however long? Turn it
off:

```
/media:config statusline.marquee off
```

### Colors

The segment ships styled by default — Claude Code statuslines render ANSI
codes, and the wrapper below passes them through untouched:

- icon and the filled part of the progress bar follow the playback state
  (green playing, yellow paused)
- **bold** title and elapsed time (the moving part stays readable), *italic*
  artist, dimmed total time, empty bar cells, app name, and output device

Only standard 16-color SGR codes are used, so everything follows your
terminal's own palette. Prefer plain text? Run
`/media:config statusline.color off` — the `NO_COLOR` environment variable is
honored too.

## Step 2 — create the wrapper script

Save as `~/.claude/statusline-media.sh` and make it executable
(`chmod +x ~/.claude/statusline-media.sh`):

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

Developing from a checkout (`claude --plugin-dir`)? Replace the `MEDIA_DIR`
block with your repo path: `np="$(/path/to/claude-media-control/scripts/media.sh statusline 2>/dev/null)"`.

## Step 3 — point settings.json at the wrapper

In `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "\"$HOME/.claude/statusline-media.sh\""
  }
}
```

**Recommended for a live-feeling statusline:** add `"refreshInterval": 1` next
to `"command"`. Statuslines normally refresh on conversation events only, so
while you are idle the elapsed time and progress bar freeze. `refreshInterval`
re-runs the command periodically; `1` (the minimum) pairs with the 1-second
segment cache so the time and bar tick every second. Drop it or raise it if you
prefer fewer redraws (each redraw also re-runs your existing statusline
command).

## Maintenance notes

- The wrapper stores a **copy** of your previous statusline command in
  `EXISTING`. If you later change your statusline setup, update that line
  too.
- To undo everything: restore your old `"statusLine"` value in
  `settings.json` and delete `~/.claude/statusline-media.sh`. Uninstalling
  the plugin makes the segment disappear on its own (the wrapper prints
  nothing when the plugin is gone), but the wrapper file itself is yours to
  remove.
- The segment honors `/media:config display.statusline off` instantly — the
  cached line is deleted on disable, no statusline restart needed.
