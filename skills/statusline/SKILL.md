---
name: statusline
description: Configure the now-playing statusline in one place — toggle items (volume, progress bar, time, output device), arrange which item sits on which line as a numeric pattern like 123/456, and style every part; bold/italic/color for the track title, artist, app, time, volume bar & percent, and output device name; playing/paused colors, bar characters, and bar length (cells) for the progress bar; the volume icon and bar shape; the output device icon; the value off hides any part. Use when the user wants to lay out, reorder, restyle, recolor, resize, hide, or redesign anything in the statusline — e.g. "make the title cyan", "title color #ff8800" (hex colors work), "hide the artist", "volume icon ♪", "bar style dots", "make the bar shorter", "reset the statusline styling".
argument-hint: [pattern like 123/456 | preset | style wish like "title bold cyan" | reset]
allowed-tools: Bash, AskUserQuestion
---

Requested arrangement or style (may be empty): $ARGUMENTS

Current items, in render order (`/` starts a new line):

!`"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config statusline.fields`

Current settings — the style table below marks customized values `*custom`
(see also `display.statusline`, `statusline.multiline`, `statusline.color`):

!`"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config`

---

## How arrangement works

`statusline.fields` is an **ordered** list — the segment renders the items in
exactly the order they are saved. A `/` in the list starts a new line
(explicit layout: each line shows exactly the items placed on it; `app`
directly after `track` folds into it as `(App)`; a line with nothing to show
disappears). Without `/`, items group automatically (`app` onto track,
adjacent `progressbar`+`time`, `output`/`volume` onto a neighbor) and
`statusline.multiline on` puts each group on its own line.

**Numeric patterns** — wherever an arrangement can be given ($ARGUMENTS, a
typed reply, an "Other" answer): digits name the items, `/` starts a new
line, digit order = display order, and digits left out are omitted:

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
Presets: **Standard** = `123456` one line, **Stacked** = `123/456` two lines
(a "compact" wish maps to `15` by intent).

## The style model

Every visible part has a `style.*` config key:

| key | part | default |
| --- | --- | --- |
| `style.track.title` | track title | `bold` |
| `style.track.artist` | artist name | `italic` |
| `style.app` | app name `(Spotify)` | `dim` |
| `style.volume.icon` | volume icon glyph | `auto` (🔈/🔉/🔊 by level) |
| `style.volume.style` | volume bar shape | `block` (▄ height bar) |
| `style.volume.bar` | volume bar on/off | `on` (draws in the accent) |
| `style.volume.percent` | volume percent `45%` | `dim` |
| `style.progressbar.playing` | bar fill + ▶︎ accent while playing | `green` |
| `style.progressbar.paused` | bar fill + ⏸ accent while paused | `yellow` |
| `style.progressbar.style` | progress bar characters | `line` |
| `style.progressbar.length` | progress bar width in cells (1–60) | `20` |
| `style.time.elapsed` | elapsed time `2:13` | `bold` |
| `style.time.total` | total-time tail `/4:24` | `dim` |
| `style.output.icon` | output device icon | `auto` (by device kind) |
| `style.output` | output device name | `dim` |

**Style spec** (the text parts): any of `bold`, `dim`, `italic`, `underline`,
plus at most one color — `black red green yellow blue magenta cyan white`,
`bright-<color>`, or an exact hex code like `#ff8800` (short `#f80` works
too; stored as `#rrggbb`, rendered as 24-bit truecolor) — or `none` (no
styling, alone), or **`off` (hide that part, alone)**. Hiding follows the part: title off drops the `—` separator, elapsed
off drops the `/` before the total, and an item whose parts are all hidden
disappears (with its line, when it sat alone on one).

**Bar characters** (`style.progressbar.style`): `line` `━━━━━━────`
(default) · `blocks` `██████░░░░` · `smooth` `█████▋░░░░` (⅛-step partial
boundary) · `rise` `█████▅░░░░` (⅛-step boundary rising bottom-up) ·
`fade` `█████▓░░░░` (⅓-step shade boundary) · `corner` `█████▙░░░░`
(¼-step quadrant boundary) · `glide` `━━━━━╾────` (half-cell steps) ·
`stipple` `⣿⣿⣿⣿⣿⣶⣀⣀⣀⣀` (⅙-step braille boundary) · `tiles`
`■■■■■◧□□□□` (half-filled square) · `dash` `━━━━━┉────` (the boundary
cracks the light line into ever finer dashes, then thickens them back
into the heavy line — `╌┄┈╍┅┉`, ⅐ steps, every step adds ink) ·
`knob` `━━━━━●────` (slider head) · `playhead` `─────╼╾───` (a one-cell
thick head gliding along a thin track in half-cell steps — aligned it
draws `━`, straddling it splits into `╼╾`; the elapsed side keeps the
accent) · `wave` `▂▄▆▄▂▄▁▁▁▁` (a
rolling swell) · `pulse` `▂▂█▁▄▂▁▁▁▁` (an ECG beat) · `eq` `▂▇▃█▅▆▁▁▁▁`
(equalizer) · `notes` `♪♫♪♫♪♫····` (marching notes) · `braille`
`⣿⣿⣿⣿⣿⣿⣀⣀⣀⣀` · `chevron` `▸▸▸▸▸▸▹▹▹▹` · `tape` `▰▰▰▰▰▰▱▱▱▱` ·
`cassette` `▮▮▮▮▮▮▯▯▯▯` · `retro` `======----` · `dots` `●●●●●●○○○○` — or
any two characters meaning "filled + empty" (`"#-"` → `######----`).
`wave`, `pulse`, `eq`, and `notes` roll forward each second while playing
and freeze on pause. **Bar length** (`style.progressbar.length`): any whole
number of cells from 1 to 60 (default `20`); the `/media:now` bar follows
it too. **Volume bar shape** (`style.volume.style`): `block` (one ▄
whose height tracks the level, default) · `progress` (an eight-cell mini
bar drawn with the progress-bar characters) · `stairs` (a `▁..█` staircase
by eighths). The
volume bar always draws in the playing/paused accent colors;
`style.volume.bar` is just its on/off switch (`on` default, `off` hides the
bar). **Icons**: `style.volume.icon` and `style.output.icon` are `auto`
(tiered by level / by device kind), `none` (hidden), or any short glyph
(`♪`, `🎵`); muted always shows 🔇.

Notes you must apply when relevant:

- SGR styles need `statusline.color` on (`NO_COLOR` always wins). Character
  choices — bar charsets, shapes, icons, and `off` — apply even with colors
  off.
- Named colors follow the terminal palette; hex codes render as 24-bit
  truecolor, which most terminals support (iTerm2, Ghostty, WezTerm, Kitty,
  VS Code) but Apple Terminal does not — if colors look wrong there, fall
  back to named colors.
- The playing/paused colors style the progress-bar fill, the ▶︎/⏸ icon in
  front of the title (the icon keeps its bold), **and** the volume bar — one
  accent across the segment. To recolor any of them, change
  `style.progressbar.playing` / `.paused`.
- Hiding a *part* (`off`) is not removing an *item*: dropping the whole
  volume/time/output item is an arrangement change (Items tab or pattern).
- cmd+click actions (the ▶︎/⏸ icon toggles, title/artist jump to the
  playing media — browser tab / Music track when scriptable, app front
  otherwise — and bar cells seek) are not a style key — a wish to turn
  clicks/links on or off ("클릭/링크 꺼줘") maps to
  `/media:config statusline.links on|off`.
- `config style.<key> reset` restores one default; `config style reset` all
  styles; `config statusline reset` additionally restores the arrangement,
  lines, colors, and marquee (the full stock look).

## Mode A — `$ARGUMENTS` is NOT empty

Arrangement requests map onto an ordered field list and save per **Step S**.
A preset name or numeric pattern maps per the tables above; an explicit list
(`time,track` or `track,app,/,time`) passes through; a described arrangement
maps by intent — "time first" → `time,progressbar,track,app`; "track and app
on line 1, the rest on line 2" → `track,app,/,volume,progressbar,time,output`.

Style wishes map onto `style.*` keys, applied one Bash call each:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config style.track.title "bold cyan"
```

Mapping guide — "제목/title" → `style.track.title`, "가수/아티스트/artist" →
`style.track.artist`, "앱/app" → `style.app`, "볼륨 바 켜/꺼/숨겨" →
`style.volume.bar on|off` (the bar's *color* follows the playing/paused
accent — a volume-bar color wish maps to `style.progressbar.playing` /
`.paused` and recolors the whole accent; say so), "볼륨 바
모양(기본/progress/계단)" → `style.volume.style` (`계단(식)`/stairs →
`stairs`, `기본`/default → `block`), "퍼센트/percent" →
`style.volume.percent`, "볼륨 아이콘" → `style.volume.icon`, "재생 색/playing
color" → `style.progressbar.playing`, "일시정지/정지 색" →
`style.progressbar.paused`, "바 스타일/문자" → `style.progressbar.style`,
"바 길이/짧게/길게/bar length" → `style.progressbar.length` (a number of
cells, 1–60; also sizes the `/media:now` bar),
"현재 시간/elapsed" → `style.time.elapsed`, "총 시간/total" →
`style.time.total`, "출력 (장치) 이름/output" → `style.output`, "출력
아이콘" → `style.output.icon`. Translate color words to the English token
(`파란색` → `blue`, `하늘색` → `cyan` or `bright-cyan`); a hex code
(`#ff8800`, `#f80`) passes through verbatim — always double-quote the value
so the shell does not treat `#` as a comment; "굵게" → `bold`,
"기울임" → `italic`, "흐리게" → `dim`, "밑줄" → `underline`, "스타일
없이/평문" → `none`; "숨겨/빼줘/미노출/hide" for a part → `off`. A
progress-bar color wish like `cyan/black` means playing `cyan` + paused
`black`; a single color sets both. When a wish names a part without saying
which attributes to keep, preserve the current non-color attributes and
change only what was asked (current `bold` + "제목을 빨간색으로" → `bold
red`). Resets: one part → `config style.<key> reset`; "스타일 전부 초기화" →
`config style reset`; "statusline 전부/배치까지 초기화" → `config statusline
reset`. If a value is refused (**exit 2**), relay the stderr reason — it
names the valid tokens — and ask for a corrected value. Never invent keys.

## Mode B — no arguments → the three-tab setup

Ask ONE **AskUserQuestion** call with exactly THREE questions — they render
as tabs. Build the option labels from the current state shown above.

- **Q1** header "Items" — `multiSelect: true`: "Which optional items should
  the statusline show? (check = shown — track & app are arranged via the
  pattern)" — exactly these options, each description stating what it looks
  like and whether it is currently shown:
  - `Volume` — `🔉 ▄ 45%`, 🔇 when muted (digit 3)
  - `Progress bar` — `━━━━━━────` (digit 4)
  - `Time` — `2:13/4:24` (digit 5)
  - `Output device` — `🎧 AirPods Pro`, icon by device kind (digit 6)

- **Q2** header "Layout" — single-select: "How should the items be arranged?
  Digits are items — 1 track · 2 app · 3 volume · 4 bar · 5 time · 6 output;
  digit order = display order, `/` starts a new line. Typing a pattern via
  Other works right away." Options (mark the one matching the current state
  in its label):
  - `Keep current — <pattern>` — no layout change; render the current field
    list as a pattern (e.g. `123/456`; `track app / time` → `1/5`)
  - `Standard — 123456` — everything on one line:
    `▶︎ Karma Police — Radiohead (Spotify)  🔉 ▄ 45%  ━━━━━━────  2:13/4:24  🎧 AirPods Pro`
  - `Stacked — 123/456` — two lines: track, app & volume / stats & output
  - `Custom…` — type any pattern into the chat next

- **Q3** header "Style" — single-select: "Restyle an item? (colors,
  bold/italic, characters, icons — `off` hides a part)" — exactly these four
  groups; mark groups holding `*custom` values in their descriptions:
  - `Track & app` — title, artist, app name
  - `Volume` — icon, bar shape & styling, percent
  - `Progress bar & time` — playing/paused colors, bar characters & length, elapsed/total
  - `Output device` — icon, device name

  (An "Other" answer here that reads like "skip"/"none"/"그대로" means no
  style change; a style wish typed there applies per Mode A instead.)

### Apply the answers, in this order

1. **Layout (Q2)**: `Keep current` → start from the current list. A preset or
   an Other-typed pattern → map per the digit legend. `Custom…` → reply with
   ONLY the digit legend table plus one line — "Type your pattern: digit
   order = display order, `/` starts a new line, leave a digit out to drop
   that item. Current: `<pattern>`" — then stop and wait; map the user's next
   message (a pattern per the legend, anything else per Mode A), then
   continue.
2. **Items (Q1) as a diff**: compare each of volume/progressbar/time/output
   against the CURRENT field list. Only act on differences: newly checked →
   append to the end of the layout from step 1 (unless the pattern already
   placed it); newly unchecked → remove it. An item whose checkbox matches
   its current visibility leaves the layout result untouched — so a
   deliberate pattern always wins.
3. **Save** (skip when nothing changed) — **Step S**:

   ```bash
   "${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" config statusline.fields "track,app,volume,/,progressbar,time,output"
   ```

   When the list has no `/` (one line), also write `statusline.multiline off`
   so a leftover stacked flag cannot re-split it; with `/`, leave
   `statusline.multiline` alone. If `display.statusline` is `off`, enable it
   (`config display.statusline on`) — the arrangement is pointless without
   the segment. Enabling also wires the segment into `~/.claude/settings.json`
   automatically (wrapper + backup; the command's output says what it did —
   relay it). If it is **refused (exit 3)**, relay the stderr reason,
   point to `/media:doctor`, keep the arrangement saved, and never bypass
   the refusal.
4. **Style (Q3)**: run the chosen group's follow-up below. Skip when the
   answer was a no-change "Other".

### Style follow-ups — one sequential AskUserQuestion per group

Ask ONE AskUserQuestion call whose questions are the group's parts (they
render as tabs). Every question's FIRST option is `Keep current (<value>)` —
a no-op. A `Default (<default>)` option maps to `config style.<key> reset`;
`Off — hide` maps to the value `off`; an "Other" answer is the style spec
itself (e.g. "bold, dim, italic, cyan" — commas are fine). Show the current
value in each question text.

- **Track & app** — 3 questions:
  - "Title" (`style.track.title`): Keep current / `Default (bold)` /
    `Off — hide the title` / Other → any spec
  - "Artist" (`style.track.artist`): Keep current / `Default (italic)` /
    `Off — hide the artist` / Other
  - "App" (`style.app`): Keep current / `Default (dim)` /
    `Off — hide the app name` / Other
- **Volume** — 4 questions:
  - "Icon" (`style.volume.icon`): Keep current / `Default — 🔈🔉🔊 by level
    (auto)` / `Hide (none)` / Other → any glyph, e.g. `🎵`
  - "Bar shape" (`style.volume.style`): Keep current / `Block ▄ (default)` /
    `Progress ━━━━────` / `Stairs ▁▂▃▄▅▆▇█` — every shape draws in the
    playing/paused accent colors
  - "Bar" (`style.volume.bar`): Keep current / `Show (on, default)` /
    `Hide (off)`
  - "Percent" (`style.volume.percent`): Keep current / `Default (dim)` /
    `Off — hide the percent` / Other
- **Progress bar & time** — 4 questions:
  - "Bar colors" (`style.progressbar.playing` / `.paused`): "playing/paused —
    `cyan/black` colors them separately, a single color sets both". Keep
    current / `Default (green / yellow)` / `cyan / black` / Other → `X/Y` or
    one color (a name or a hex code like `#ff8800`)
  - "Bar characters" (`style.progressbar.style`): Keep current /
    `Line ━━━━━━──── (default)` / `Blocks ██████░░░░` / Other → `smooth`,
    `rise`, `fade`, `corner`, `glide`, `stipple`, `tiles`, `dash`,
    `knob`, `playhead`, `wave`, `pulse`, `eq`, `notes`,
    `braille`, `chevron`, `tape`, `cassette`, `retro`, `dots`, or any
    two glyphs like `#-`
  - "Bar length" (`style.progressbar.length`): Keep current /
    `Default (20 cells)` / `10 — the pre-0.20 width` / Other → any whole
    number of cells, 1–60 (the `/media:now` bar follows it)
  - "Time" (`style.time.elapsed` / `style.time.total`): "elapsed/total —
    `bold cyan/dim` styles them separately (`X/Y`); `off` as the total
    hides the `/total` tail". Keep current / `Defaults (bold / dim)` /
    `Elapsed only — total off` / Other → `X/Y`
- **Output device** — 2 questions:
  - "Icon" (`style.output.icon`): Keep current / `Default — by device kind
    (auto)` / `Hide (none)` / Other → any glyph
  - "Name" (`style.output`): Keep current / `Default (dim)` /
    `Off — icon only` / Other

Apply every non-Keep answer with `config style.<key> …` Bash calls (exit 2 →
relay the stderr reason and re-ask that one value). Offer to continue with
another group only if the user asked for more than one.

## Show the result

```bash
NO_COLOR=1 "${CLAUDE_PLUGIN_ROOT}/scripts/media.sh" statusline
```

Show the segment in a fenced code block (plain glyphs here; the real
statusline is ANSI-styled) and report what changed — the saved pattern and/or
each style key old → new. Colors cannot render in chat: the live statusline
picks every change up within a second (each write drops the segment cache),
so tell the user to glance at it. If a changed style is SGR-only while
`statusline.color` is `off`, point that out (`config statusline.color on`).
If `statusline` prints nothing, nothing is playing — the setup is saved and
shows once something plays. Close with one reminder when relevant: enabling
wired the segment into the statusline automatically (no restart needed;
details in `docs/statusline.md`); quick on/off toggles and the full reset
live in `/media:config`.
