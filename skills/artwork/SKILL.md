---
name: artwork
description: Show the album artwork (cover art) of the currently playing track. Use when the user asks to see the album art, cover image, or artwork of what's playing.
allowed-tools: Bash, Read
---

Artwork fetch result (JSON):

!`"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" artwork`

- If the JSON has a `path`: display the image by using the Read tool on that
  exact path, then caption it in one line: `<title> — <artist>` (run
  `"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" now` with Bash only if you still
  need the track info).
- If the JSON is `null`: the current track has no artwork, or nothing is
  playing — tell the user which (check `media.sh now` if unsure).
- If the command failed: relay the stderr hint briefly. Artwork requires the
  native helper (the fallback cannot read it) — point to `/media:doctor`.

The image file lives under `$TMPDIR` and is overwritten on each call; never
paste its contents as base64 into the conversation.
