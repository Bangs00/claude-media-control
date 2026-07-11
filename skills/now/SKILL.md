---
name: now
description: Show what's currently playing on this Mac (any app — Spotify, Apple Music, browsers). Use when the user asks what song/track/music is playing, who the artist is, or wants playback status.
allowed-tools: Bash
---

Current system-wide now-playing state (JSON):

!`"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" now`

Progress bar display setting (on/off):

!`"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config display.progressbar`

Progress bar characters (`style.progressbar.style`):

!`"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config style.progressbar.style`

Progress bar length in cells (`style.progressbar.length`):

!`"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config style.progressbar.length`

Present the state to the user exactly in this format, as plain markdown lines — NOT inside a code block, so the bold/italic styling renders:

- Line 1: `▶︎ **<title>** — *<artist>* · <appName>` — use `▶︎` when `playing` is true, `⏸` when false; title bold, artist italic. If `appName` is missing, use `bundleIdentifier`.
- Line 2 (only when the progress bar setting is `on` AND `duration` is present): a bar of exactly as many characters as the length value above (default 20) — filled (elapsed) + empty (remaining) using the ratio `elapsedTimeNow / duration`, then two spaces and `**m:ss** / m:ss` (elapsed time bold). The bar characters follow the bar-style value above — `line` → `━`/`─`, `blocks` → `█`/`░`, `smooth` → `█` fill and `░` empty with the boundary cell a partial block (`▏▎▍▌▋▊▉` by eighths of the remainder), `rise` → `█` fill and `░` empty with the boundary cell a partial block rising bottom-up (`▁▂▃▄▅▆▇` by eighths of the remainder), `fade` → `█`/`░` with the boundary cell a shade (`▒▓` by thirds of the remainder), `corner` → `█`/`░` with the boundary cell filling by quadrants (`▖▌▙` by quarters of the remainder), `glide` → `━`/`─` with the boundary cell `╾` (halves of the remainder), `stipple` → `⣿`/`⣀` with the boundary cell rising braille dots (`⣄⣤⣦⣶⣷` by sixths of the remainder), `tiles` → `■`/`□` with the boundary cell `◧` (halves of the remainder), `dash` → `━`/`─` with the boundary cell cracking into ever finer light dashes then thickening back through heavy ones (`╌┄┈╍┅┉` by sevenths of the remainder), `knob` → `━` fill with `●` as the last filled cell and `─` empty, `playhead` → every cell `─` except a one-cell thick head: its left edge sits at round(ratio × (2×length − 2)) half-cells — an even count parks it aligned as `━` on cell count/2 (0-based), an odd count splits it as `╼╾` across cells (count−1)/2 and (count+1)/2, `wave` → filled cells repeat `▂▄▆▄` with `▁` empty, `pulse` → filled cells repeat `▂▂█▁▄` with `▁` empty, `eq` → filled cells repeat `▂▇▃█▅▆` with `▁` empty, `notes` → filled cells repeat `♪♫` with `·` empty, `braille` → `⣿`/`⣀`, `chevron` → `▸`/`▹`, `tape` → `▰`/`▱`, `cassette` → `▮`/`▯`, `retro` → `=`/`-`, `dots` → `●`/`○`, any other two-character value → first char filled, second empty — so this bar matches the statusline segment. The elapsed `m:ss` is ALWAYS `elapsedTimeNow` (use `elapsedTime` only when `elapsedTimeNow` is absent) — `elapsedTime` is the app's last snapshot and can lag minutes behind; the statusline segment shows `elapsedTimeNow`, so anything else here would contradict it. The total `m:ss` is `duration`.
- If `duration` is absent (live stream): skip the bar, show `**m:ss** / LIVE` (same elapsed rule).
- If the JSON is `null`: tell the user nothing is playing right now.
- If the JSON contains `"degraded": true` or a stderr hint appeared: add one short note that the plugin is in fallback mode and `/media:doctor` has details.

Example (the markdown you output):

```markdown
▶︎ **Neon Horizon** — *Midnight Arcade* · Firefox
━━━━━━━━━━━─────────  **2:07** / 3:48
```
