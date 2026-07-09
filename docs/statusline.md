# Now-playing in your statusline

Show the current track as an extra line in Claude Code's statusline:

```
[your existing statusline, untouched]
▶︎ Karma Police — Radiohead  2:13/4:24
```

The segment comes from `media.sh statusline`, which answers from a small TTL
cache (default 5s) in well under 50ms — it never slows your statusline down.
The real now-playing read runs at most once per TTL window.

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

Optional: add `"refreshInterval": 5` next to `"command"` if you want the
elapsed time to tick while you are idle. Statuslines normally refresh on
conversation events only; `refreshInterval` adds periodic re-runs, and values
below the 5-second segment TTL just replay the cache.

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
