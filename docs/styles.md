# Statusline style gallery

**English** | [한국어](styles.ko.md) | [日本語](styles.ja.md) | [简体中文](styles.zh-CN.md)

Every visual detail of the now-playing segment is a config key. This page
shows **all of them, with what you get**. Two ways to change anything:

```
/media:statusline                              # guided — or just say it:
                                               #   "bar style dots", "hide the artist"
/media:config style.progressbar.style wave     # or set a key directly
```

Changes show up on the next statusline tick (≤ 1s). No restart, ever.
`media.sh config style` lists every key, current value, and default.

## Anatomy of the segment

```
▶︎ Karma Police — Radiohead (Spotify)  🔉 ▄ 45%  ━━━━━━━━━━━━────────  2:13/4:24  🎧 AirPods Pro
```

| You see | Key | Default |
| --- | --- | --- |
| `▶︎` / `⏸` state icon | colored by `style.progressbar.playing` / `.paused` | `green` / `yellow` |
| `Karma Police` | `style.track.title` | `bold` |
| `— Radiohead` | `style.track.artist` | `italic` |
| `(Spotify)` | `style.app` | `dim` |
| `🔉` volume icon | `style.volume.icon` | `auto` |
| `▄` volume bar | `style.volume.style` (shape) · `style.volume.bar` (show) | `block` · `on` |
| `45%` | `style.volume.percent` | `dim` |
| `━━━━━━━━━━━━────────` | `style.progressbar.style` (characters) · `style.progressbar.length` (cells) | `line` · `20` |
| `2:13` elapsed | `style.time.elapsed` | `bold` |
| `/4:24` total | `style.time.total` | `dim` |
| `🎧` output icon | `style.output.icon` | `auto` |
| `AirPods Pro` | `style.output` | `dim` |

(Which items appear, and on which line, is the *arrangement* — that lives in
[statusline.md](statusline.md#arrange-what-the-segment-shows).)

One **accent color** runs through the whole segment: the ▶︎/⏸ icon, the
progress-bar fill, and the volume bar all draw in
`style.progressbar.playing` while playing and `.paused` while paused.

## Progress bar

`style.progressbar.style` picks the characters, `style.progressbar.length`
how many cells wide the bar is (default 20). The `/media:now` reply draws
its bar with the same characters and length, so the two always match.
Character and length choices apply even with colors off.

![The bar presets, volume shapes, and a hex accent, drawn live at one frame per second](styles.gif)

### Static presets

Shown at 60% (`smooth` and `rise` at 58%, where their partial cells show):

| Value | Looks like | |
| --- | --- | --- |
| `line` | `━━━━━━━━━━━━────────` | the default |
| `blocks` | `████████████░░░░░░░░` | the classic (pre-0.12 default) |
| `smooth` | `███████████▋░░░░░░░░` | boundary cell is a partial block — see below |
| `rise` | `███████████▅░░░░░░░░` | boundary cell rises bottom-up — see below |
| `knob` | `━━━━━━━━━━━●────────` | a slider head caps the fill |
| `braille` | `⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣀⣀⣀⣀⣀⣀⣀⣀` | |
| `chevron` | `▸▸▸▸▸▸▸▸▸▸▸▸▹▹▹▹▹▹▹▹` | |
| `tape` | `▰▰▰▰▰▰▰▰▰▰▰▰▱▱▱▱▱▱▱▱` | |
| `cassette` | `▮▮▮▮▮▮▮▮▮▮▮▮▯▯▯▯▯▯▯▯` | |
| `retro` | `============--------` | plain ASCII |
| `dots` | `●●●●●●●●●●●●○○○○○○○○` | |

`smooth` fills in ⅛-cell steps, so short tracks progress visibly between
seconds:

```
 3%  ▋░░░░░░░░░░░░░░░░░░░
47%  █████████▍░░░░░░░░░░
98%  ███████████████████▋
```

`rise` takes the same ⅛ steps bottom-up — each cell climbs ▁▂▃▄▅▆▇
before it completes:

```
 3%  ▅░░░░░░░░░░░░░░░░░░░
47%  █████████▃░░░░░░░░░░
98%  ███████████████████▅
```

### Animated presets

These four roll toward the empty end once per second while playing, and
freeze on pause:

| Value | t | t+1s | t+2s | |
| --- | --- | --- | --- | --- |
| `wave` | `▂▄▆▄▂▄▆▄▂▄▆▄▁▁▁▁▁▁▁▁` | `▄▂▄▆▄▂▄▆▄▂▄▆▁▁▁▁▁▁▁▁` | `▆▄▂▄▆▄▂▄▆▄▂▄▁▁▁▁▁▁▁▁` | a rolling swell |
| `pulse` | `▂▂█▁▄▂▂█▁▄▂▂▁▁▁▁▁▁▁▁` | `▄▂▂█▁▄▂▂█▁▄▂▁▁▁▁▁▁▁▁` | `▁▄▂▂█▁▄▂▂█▁▄▁▁▁▁▁▁▁▁` | an ECG beat |
| `eq` | `▂▇▃█▅▆▂▇▃█▅▆▁▁▁▁▁▁▁▁` | `▆▂▇▃█▅▆▂▇▃█▅▁▁▁▁▁▁▁▁` | `▅▆▂▇▃█▅▆▂▇▃█▁▁▁▁▁▁▁▁` | equalizer bars |
| `notes` | `♪♫♪♫♪♫♪♫♪♫♪♫········` | `♫♪♫♪♫♪♫♪♫♪♫♪········` | `♪♫♪♫♪♫♪♫♪♫♪♫········` | marching notes |

### Your own characters

Any **exactly two characters** mean "filled + empty" (a space works as the
empty half; two spaces, tabs, and newlines are refused):

```
/media:config style.progressbar.style "#-"     →  ############--------
/media:config style.progressbar.style "~ "     →  ~~~~~~~~~~~~
```

### Bar length

`style.progressbar.length` sets how many cells the bar spans — any whole
number from 1 to 60 (default `20`):

```
/media:config style.progressbar.length 10   →  ━━━━━━────
/media:config style.progressbar.length 40   →  ━━━━━━━━━━━━━━━━━━━━━━━━────────────────
```

One length drives both bars — the statusline segment and the `/media:now`
reply. With links on every cell stays ⌘+clickable, so a longer bar simply
seeks in finer steps. (The volume mini bar keeps its eight cells — one
per volume step.) The default grew from 10 to 20 in 0.20.0; set `10`
to bring back the compact pre-0.20 bar.

### Bar colors

`style.progressbar.playing` (default `green`) and `.paused` (default
`yellow`) color the fill — and with it the ▶︎/⏸ icon and the volume bar,
since the segment shares one accent. Empty cells stay dim.

```
/media:config style.progressbar.playing bright-cyan
/media:config style.progressbar.playing "#1db954"   # or any exact hex color
/media:config style.progressbar.paused magenta
```

## Volume

The `volume` item renders **icon + bar + percent** (`🔉 ▄ 45%`); when muted
it collapses to `🔇` alone. (It needs the native helper — see
`/media:doctor`.)

### Bar shapes — `style.volume.style`

| Value | 10% | 20% | 35% | 50% | 60% | 75% | 85% | 100% | |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `block` | `▁` | `▂` | `▃` | `▄` | `▅` | `▆` | `▇` | `█` | one cell, height = level (default) |
| `stairs` | `▁` | `▁▂` | `▁▂▃` | `▁▂▃▄` | `▁▂▃▄▅` | `▁▂▃▄▅▆` | `▁▂▃▄▅▆▇` | `▁▂▃▄▅▆▇█` | eighth steps |
| `progress` | `━───────` | `━━──────` | `━━━─────` | `━━━━────` | `━━━━━───` | `━━━━━━──` | `━━━━━━━─` | `━━━━━━━━` | 8-cell mini bar |

`progress` draws with your progress-bar characters, animation and all —
`blocks` gives `████░░░░`, `dots` gives `●●●●○○○○`. The volume bar always draws
in the playing/paused accent; `style.volume.bar off` hides just the bar
(`🔉 45%`).

### Volume icon — `style.volume.icon`

| Value | Looks like |
| --- | --- |
| `auto` (default) | `🔈` low · `🔉` mid · `🔊` high · `🔇` at zero |
| `none` | hidden — `▄ 45%` |
| any glyph, e.g. `♪` | `♪ ▄ 45%` |

Muted always shows `🔇`, whatever the icon setting.

### Percent — `style.volume.percent`

A text style (default `dim`), or `off` to drop it: `🔉 ▄`.

## Output device

The `output` item is icon + device name: `🎧 AirPods Pro`.

| Key | Values |
| --- | --- |
| `style.output.icon` | `auto` (default) = by device kind: `🎧` Bluetooth & headphone jack · `📺` HDMI/DisplayPort · `📶` AirPlay · `🔊` speakers — or `none`, or any glyph |
| `style.output` | text style for the name (default `dim`), or `off` for icon-only |

## Text styles

Every text part — title, artist, app, elapsed/total time, volume percent,
output name — takes a **style spec**:

- any of `bold`, `dim`, `italic`, `underline`
- plus at most one color: `black` `red` `green` `yellow` `blue` `magenta`
  `cyan` `white` or `bright-<color>` (your terminal's palette decides the
  actual shades), or an exact hex code — `#ff8800`, short `#f80` — rendered
  as 24-bit truecolor (most terminals support it; Apple Terminal does not)
- or `none` — no styling at all
- or `off` — **hide that part**

```
/media:config style.track.title "bold bright-cyan"
/media:config style.track.title "bold #ff8800"   # exact color — quote the hex
/media:config style.track.artist off
```

Hiding tidies up after itself: a hidden title takes the `—` separator with
it, a hidden elapsed time drops the `/` before the total, and an item whose
parts are all hidden disappears entirely. (To drop a whole item, change the
arrangement instead — `/media:statusline`.)

Style specs render only while `statusline.color` is on (`NO_COLOR` wins);
character choices — bar charsets, shapes, icons — and `off` apply
regardless.

## Recipes

Four looks, ready to paste. Colors don't show on this page — glance at your
statusline.

**Minimal** — title and elapsed time, nothing else:

```
/media:config statusline.fields "track,time"
/media:config style.track.artist off
/media:config style.time.total off
```
```
▶︎ Karma Police  2:13
```

**Night drive** — neon dots on cyan:

```
/media:config style.progressbar.style dots
/media:config style.progressbar.playing bright-magenta
/media:config style.track.title "bold bright-cyan"
```
```
▶︎ Karma Police — Radiohead (Spotify)  ●●●●●●●●●●●●○○○○○○○○  2:13/4:24
```

**Tape deck** — cassette bar, stair volume, note icon:

```
/media:config statusline.fields "track,app,volume,progressbar,time"
/media:config style.progressbar.style tape
/media:config style.volume.style stairs
/media:config style.volume.icon ♪
```
```
▶︎ Karma Police — Radiohead (Spotify)  ♪ ▁▂▃▄ 45%  ▰▰▰▰▰▰▰▰▰▰▰▰▱▱▱▱▱▱▱▱  2:13/4:24
```

**Plain terminal** — ASCII bar, no colors:

```
/media:config style.progressbar.style retro
/media:config statusline.color off
```
```
▶︎ Karma Police — Radiohead (Spotify)  ============--------  2:13/4:24
```

## Back to defaults

```
/media:config style.track.title reset     # one key
/media:config style reset                 # every style.* key
/media:config statusline reset            # styles + arrangement, lines,
                                          # colors, marquee — the stock look
```
