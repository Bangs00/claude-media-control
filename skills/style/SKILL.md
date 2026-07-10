---
name: style
description: Customize how each statusline item looks — bold/italic/color for the track title, artist, app name, current/total time, volume bar & percent, and output device; playing/paused colors and the bar character style (blocks/wave/line/dots or any two glyphs) for the progress bar; and the volume icon. Use when the user wants to change statusline colors, make something bold/italic, restyle the progress bar, change the volume icon, or reset the statusline styling.
argument-hint: [wish, e.g. "title bold cyan" or "bar style wave" | reset]
allowed-tools: Bash, AskUserQuestion
---

Requested style change (may be empty): $ARGUMENTS

Current styles (custom values are marked `*custom`):

!`"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config style`

Color master switch (`statusline.color` — SGR styles render only when on):

!`"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config statusline.color`

---

## The style model

Every visible part of the statusline segment has a `style.*` config key:

| key | part | default |
| --- | --- | --- |
| `style.track.title` | track title | `bold` |
| `style.track.artist` | artist name | `italic` |
| `style.app` | app name `(Spotify)` | `dim` |
| `style.volume.icon` | volume icon glyph | `auto` (🔈/🔉/🔊 by level) |
| `style.volume.bar` | volume level bar `▄` | `dim` |
| `style.volume.percent` | volume percent `45%` | `dim` |
| `style.progressbar.playing` | bar fill + ▶︎ accent while playing | `green` |
| `style.progressbar.paused` | bar fill + ⏸ accent while paused | `yellow` |
| `style.progressbar.style` | progress bar characters | `line` |
| `style.time.elapsed` | elapsed time `2:13` | `bold` |
| `style.time.total` | total-time tail `/4:24` | `dim` |
| `style.output` | output device (icon + name) | `dim` |

**Style spec** (all keys except the two below): any of `bold`, `dim`,
`italic`, `underline`, plus at most one color — `black red green yellow blue
magenta cyan white` or `bright-<color>` — or `none` (no styling, alone).
Standard 16-color SGR only, so colors follow the user's terminal palette.

**Bar characters** (`style.progressbar.style`): `line` `━━━━━━────`
(default) · `blocks` `██████░░░░` · `wave` `~~~~~~----` · `dots`
`●●●●●●○○○○` — or any two characters meaning "filled + empty", e.g. `"#-"`
→ `######----`.

**Volume icon** (`style.volume.icon`): `auto` (🔈/🔉/🔊 tiered by level, 🔇
at zero), `none` (hide the icon), or any short glyph (e.g. `"♪"`). Muted
always shows 🔇.

Notes you must apply when relevant:

- SGR styles need `statusline.color` on (`NO_COLOR` in the environment always
  wins). `style.progressbar.style` and `style.volume.icon` change
  *characters*, so they show even with colors off.
- The playing/paused colors style the progress-bar fill **and** the ▶︎/⏸
  icon in front of the title (the icon keeps its bold on top) — one accent,
  consistent across the segment.
- Styles restyle the items the statusline already shows; which items appear
  and on which lines is `/media:statusline`, on/off toggles are
  `/media:config`.

## Mode A — `$ARGUMENTS` is NOT empty

Map the wish onto key/value pairs and apply each with one Bash call:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config style.track.title "bold cyan"
```

Mapping guide — "제목/title" → `style.track.title`, "가수/아티스트/artist" →
`style.track.artist`, "앱/app" → `style.app`, "볼륨 바" → `style.volume.bar`,
"퍼센트/percent" → `style.volume.percent`, "볼륨 아이콘" →
`style.volume.icon`, "재생 색/playing color" → `style.progressbar.playing`,
"일시정지/정지 색" → `style.progressbar.paused`, "바 스타일/모양" →
`style.progressbar.style`, "현재 시간/elapsed" → `style.time.elapsed`, "총
시간/total" → `style.time.total`, "출력/출력장치/output" → `style.output`.
Translate color words to the English token (`파란색` → `blue`, `하늘색` →
`cyan` or `bright-cyan`); "굵게" → `bold`, "기울임" → `italic`, "흐리게" →
`dim`, "밑줄" → `underline`, "스타일 없이/평문" → `none`. When a wish names a
part without saying which attribute to keep, preserve the part's current
non-color attributes and change only what was asked (e.g. current `bold` +
"제목을 빨간색으로" → `bold red`).

Resets: "reset"/"초기화" for one part → `config style.<key> reset`; for
everything → `config style reset`.

If a value is refused (**exit 2**), relay the stderr reason — it names the
valid tokens — and ask for a corrected value. Never invent new keys.

## Mode B — no arguments → interactive styling

Do NOT use AskUserQuestion for this — twelve parts times attributes and
sixteen colors cannot fit 4-option questions, and free text is faster. Reply
with (translated to the conversation language, keep the table):

1. The current-styles table above, reduced to three columns: part (human
   name), key, current value (mark customized values).
2. This prompt shape:

   > Tell me what to change, in plain words — e.g. "title bold cyan", "가수는
   > 기울임 없이 노란색", "bar style wave", "볼륨 아이콘 ♪", "재생 색을
   > bright-blue로", "제목만 기본값으로" (one part back to its default),
   > "전부 초기화" (everything back to defaults).
   > Styles: bold · dim · italic · underline · none + one color (black red
   > green yellow blue magenta cyan white, bright-…) — bar characters:
   > blocks · wave `~~~~--` · line `━━──` · dots `●●○○` or any two glyphs.
   > Every part resets individually: `<part> reset` restores just that one.

3. Stop and wait for the user's next message, then treat it as Mode A.

## Step 2 — show the result

After applying, re-run:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config style
```

Report the changed keys (old → new). The live statusline picks the change up
within a second (the segment cache is dropped on every style write) — tell
the user to glance at it, since chat output cannot render the actual colors.
If `statusline.color` is `off` and the change was an SGR style (not a
charset/icon), point that out and offer:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config statusline.color on
```

If `display.statusline` is `off`, mention the styles are saved but the
segment itself is disabled (`/media:config display.statusline on` +
`docs/statusline.md` wrapper to see it).
