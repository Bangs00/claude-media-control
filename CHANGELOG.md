# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning is
[SemVer](https://semver.org/spec/v2.0.0.html), tracked in
`.claude-plugin/plugin.json`.

## [0.38.1] — 2026-07-16

### Fixed

- **The twelve recipes added in 0.38.0 now read like a native wrote them.**
  The copyedit pass that polished this gallery shipped in 0.28.0; 0.38.0's
  twelve new looks landed long after it and went out in raw translation. 45
  prose lines across the Korean, Japanese and Chinese pages are rewritten —
  the English page, every code block, config value and rendered example are
  untouched.

  The dominant defect was invented vocabulary: each new section coined a term
  where the style gallery had long since settled one — `판` over `버전`, `머리`
  over `헤드`, `융기` over `봉우리`, `중심선` over `기준선`; `系統` over `系`,
  `進捗` over `進み具合`, `隆起` over `ふくらみ`, `相方` over `双子`; `小生灵`
  over `小动物`, `底线`/`中线` over `底部`/`居中的基线`. The Korean page also
  drifted between `셀` and `칸` for a terminal cell, which the style gallery
  calls `칸` throughout. The rest was translation-ese — English colon-lists
  left as trailing fragments in Korean (`문서로 남은 표준에서요`), noun-phrase
  headlines flattened into predicates in Japanese so the em-dash apposition
  had nothing left to attach to, a stacked-`的` relative clause and a needless
  `被` in Chinese.

  Three of the fixes are factual rather than stylistic:

  - **`stipple` is not a half-cell preset.** The Chinese page called it
    `半格孪生`, but `半格` is this project's ½ term for `glide` — the word the
    Vernier recipe itself uses two sections later. `stipple` is a `子格` preset
    at ⅙, and now says so.
  - **A seiche shows 2.5 waves, not two half-waves.** `两个半波` reads as two
    `半波`, which is a real term in a standing-wave context. The rendered bar
    runs a period of 8 cells across 20, so 2.5 cycles is the number.
  - **A power amp has no tuner dial.** Dial's Chinese text called the
    silver-face receiver a `功放` and its scale a `调谐盘`, contradicting both
    itself and the page's own intro, which says `调谐刻度盘`.

  0.38.0 had also re-touched two lines the 0.28.0 pass already polished,
  reverting `앰버 인광 버전` to `앰버 인광 사촌` and `调谐刻度盘` to `调谐盘`.
  Both are restored.

## [0.38.0] — 2026-07-16

### Added

- **Twelve more recipes, and the gallery finally reaches every preset.**
  [`docs/recipes.md`](docs/recipes.md) shipped twelve looks in 0.27.0 and then
  never caught up with the bar: 0.31.0 added the length-adaptive waveforms and
  the audio visualizers, 0.32.0 their braille twins, 0.33.0 whole-bar notes,
  0.34.0–0.35.0 the ECG family, 0.37.0 the sprites. Of 36 charsets the page
  reached ten. It has twenty-four recipes now, and every charset is in one of
  them.

  Each new look is grounded the way the first twelve were — in something whose
  *behaviour* forces the preset rather than decorating it. **Lead II** is
  `heartbeat` at chart speed: ECG paper runs at 25 mm/s the world over, so a
  longer strip shows more beats and never a wider one — which is exactly why
  the beat is pinned at 10 cells while every other waveform scales with the
  bar. **Third-octave** is `spectrum`: an analyser's bands sit on fixed ISO
  centres and dance in place, which is why `spectrum` alone among the field
  presets does not stretch. **Seiche** is `wave`: a standing wave fits its
  basin whatever the width, so 2.5 cycles at any length is the physics, not a
  compromise. **Vernier** is `glide` — an instrument built in 1631 to read
  *between* the graduations. **Telegraph** is `dash`, where a dash is three
  dots fused, which is what the boundary cells do. Then **Plasma** `blocks` ·
  **Goban** `dots` · **Service** `chevron` · **Platform** `tiles` · **Slider
  wall** `bars` · **Ripple tank** `mirror` · **Neko** `cat`.

  Twins and boundary variants ride along as one-line swaps inside their kin's
  recipe rather than padding the page with near-identical entries, so `swell`
  `cava` `ripple` `monitor` `ekg` `snake` `duck` `bird` `sprite` `rise` `fade`
  `corner` `braille` and `stipple` all have somewhere to live.

  Colors are derived from the referent instead of borrowed from a theme:
  Plasma's orange is neon's own two strong visible lines (585 and 640 nm),
  Third-octave's red is the first visible LED's (GaAsP, 655 nm), Lead II's
  green is a long-persistence display phosphor. That is a provenance the page
  can state, rather than a resemblance it has to hope nobody checks.

### Changed

- **The whole gallery was re-recorded on one geometry.** The 0.27.0 gifs came
  from a vhs that no longer exists here: it drew 11.452 px per display cell and
  a rounded window border, and vhs 0.11.0 — current stable — draws 13.2 and has
  no `Set BorderRadius` at all. Twelve new gifs at the new metrics beside
  twelve old ones at the old would have read as two galleries, so all
  twenty-four are the current renderer through the current tool. The rig now
  computes each gif's width from the line it actually draws, measured against
  an 80-column ruler; without that the segment wraps, the top line scrolls off,
  and you record an empty box.

- **`heartbeat`/`monitor`'s colors-off tail "runs isoelectric" now, not
  "flatlines".** Isoelectric is the clinical term and the accurate one: the TP
  segment of every healthy beat is flat, so a flat trace is a heart resting
  between beats, not the absence of one. Same behaviour, better word, in all
  four languages. Lead II's paused colour is deliberately neither red nor
  yellow for the same reason — on a monitor those two are standardised
  alarm-priority colours (IEC 60601-1-8), and a paused song is not an alarm.

- **Twilight's palette moved off its exact source, and the doc stopped
  advertising it.** The six hex values were, to the digit, Tokyo Night's
  (MIT, © Enkia), and the page then called them "in exact hex". Colour values
  are not copyrightable — 37 CFR §202.1(a) excludes "mere variations of ...
  coloring" outright — so nothing was ever owed. But keeping the values *and*
  saying nothing was the one combination that is legally fine and socially
  poor. Each value is nudged 1–3%: the look is unchanged, the provenance is no
  longer someone else's.

- **The style gallery's hex example is no longer a brand colour.** `#1db954`
  was Spotify's (legacy) green, sitting in a media plugin's own docs as the
  example of "any exact hex color" — the one spot on the page with a
  goods-and-services nexus behind it. It is `#3ddc84` now, which is nobody's.

### Fixed

- **The Synthwave preview had been drawing a `pulse` that no longer exists.**
  0.34.0 redrew `pulse` as a real ECG trace and re-recorded the gifs, but the
  plain-text preview underneath kept the pre-0.34.0 shape,
  `▃▂▂▂▂▂▂▇▃▂▂▂▂▂▂▇▃▂▂▂` — stale for four releases, in all four languages. It
  reads `▄▁▁▁▁▁▁█▁▁▄▁▁▁▁▁▁█▁▁` now, which is what the renderer actually draws.
  Every preview and every config line on the page is checked against the real
  thing before it ships.

## [0.37.0] — 2026-07-15

### Added

- **Sprite progress bars: something walks the track, and where it stands is
  the progress.** `cat` `━━━━━━ᓚᘏᗢ┈┈┈┈┈┈┈┈┈┈┈` · `snake` · `duck` · `bird` —
  four presets that walk the bar instead of filling it. It is the `playhead`
  idea with something alive in place of the thick head, and it inherits that
  preset's best property: position alone carries the progress, so a sprite
  reads exactly the same with colors off. Each walks its own track — the cat a
  dotted road, the duck water.

  The gait cycles once a second while playing and holds still when paused,
  which is the whole reason the frames exist: at length 20 a four-minute track
  only steps cells every 13 seconds, and a creature that moved once every 13
  seconds would read as broken rather than alive. The frames come off
  `int(elapsed)`, so the freeze on pause is the same trick the waveform drift
  already used — no flag, nothing to keep in sync.

  Drawn in Canadian Aboriginal Syllabics rather than emoji, which is what makes
  them work: emoji are two columns wide and all of 🐈🐕🚗 face *left*, so they
  moonwalk down a bar that fills rightward. `ᓚᘏᗢ` is one cell per glyph, faces
  the way it walks, and sits on the same baseline as the track. No monospace
  font carries the syllabics, but macOS falls back to Euphemia UCAS and the
  terminal squeezes it into its cell, so the grid holds.

- **`sprite`: bring your own.** Three keys, the sprite-family answer to the
  two-character custom charset. `style.progressbar.sprite` takes the frames it
  cycles through — `"ᓚᘏᗢ ᓚᘐᗢ"`, up to eight, in the order given — and a single
  frame simply never animates, which makes it a `knob` whose glyph is anything
  you like (`"🚀"` walks the bar without moving a muscle). `style.progressbar.trail`
  and `style.progressbar.track` are the walked and untravelled halves of the
  track, one narrow glyph each. Emoji frames work: width is counted in columns,
  not characters, so a two-column rocket spends two cells and the bar still
  spans exactly `style.progressbar.length`.

### Changed

- `docs/statusline.md` and the README said 31 progress-bar charsets; they now
  say 36. The `/media:statusline` style picker offers the sprites, and asks for
  the frames when the chosen style is `sprite`.

## [0.36.0] — 2026-07-15

### Fixed

- **The statusline dragged instead of ticking once a second, and the animated
  presets showed it.** The segment cached its own rendered line for a second
  — but the rendered line *is* the animation frame: the waveform presets take
  their phase from the playback position, so a cached line is a frozen beat,
  and roughly every other tick served one. The cache barely worked as a cache
  either: it compared whole seconds against a `refreshInterval` of 1, so ticks
  a second apart aged out almost every time (measured: 1 hit in 10), and each
  miss paid ~430ms to rebuild the line — ~290ms of it a MediaRemote round-trip
  for a position the clock already knew. Claude Code cancels a tick still
  running when the next one fires, so a busy session dropped frames outright.

  What is cached now is the **read**, not the line. Every tick re-renders and
  advances the position locally, the same extrapolation `adapter.m` already
  does from the app's own snapshot — so frames stay exact while the real read
  happens at most every 2 seconds, in the background, with nothing waiting on
  it. Measured on one machine at matched load, 12 ticks a second apart with
  `heartbeat`: frames advancing went from **5/11 to 11/11**, and a tick from
  **531ms to 92ms** (5.8×). A paused track still holds still.
- **`/media:now` read the Mac twice.** `now` and `bar` each paid their own
  ~290ms round-trip; `bar` now reuses the read `now` just cached (~60ms).

### Added

- **`statusline.links` switches each clickable part on its own.** It used to
  be all-or-nothing. `toggle` (the ▶︎/⏸ icon), `track` (title — artist), `app`
  (the app name) and `seek` (the progress bar) are now independent:

  ```bash
  /media:config statusline.links toggle,seek     # clickable icon + bar, plain text
  /media:config statusline.links track,app       # clickable text, plain icon + bar
  ```

  `on` and `off` still mean every part and none, a `true`/`false` already in
  your config still reads as it always did, and a part left out renders
  byte-identically to links off entirely.

### Changed

- Only what changes a *reading* of the Mac now invalidates anything: a control
  click, `seek`, a volume or output switch drop the cached read so the next
  tick re-reads. Appearance changes — styles, arrangement, colors, marquee —
  need no invalidation at all any more, because the segment is built from
  scratch on every tick.

## [0.35.0] — 2026-07-15

### Added

- **`heartbeat` and `monitor` progress-bar presets — an ECG around a centre
  baseline.** `pulse` and `ekg` draw their ECG up from a floor, so their QRS
  can only rise; these two ride a centre line, which buys the move the other
  pair cannot make — the S wave carries straight through the line and spikes
  *below* it: `━━━━┻┳━━━━━━━━┻┳━━━━`. Twins, like the existing pairs —
  `heartbeat` draws with box-drawing stems, `monitor` with a braille trace
  (`⠤⠤⠤⠴⠼⡦⠤⠶⠤⠤`) — over one shared beat. Alone among the waveforms their
  shape does **not** follow the bar width: the beat stays 10 cells apart at
  any length, so a longer bar shows more beats rather than one stretched
  beat. Both span the whole bar; with `statusline.color` off the unplayed
  tail settles onto the baseline — it flatlines.
- **`media.sh bar`** prints the progress bar on its own, without colors or
  click links.

### Fixed

- **`/media:now` and the statusline can no longer disagree about the bar.**
  The skill carried a preset → glyphs table for Claude to draw from, and it
  drifted every time the presets moved — 0.31.1, 0.32.0, 0.33.0 and 0.34.0
  each had to rewrite it. The table was never going to hold: it can say
  `line` → `━`/`─`, but the waveforms are computed from the playback position
  and the bar width, and no prose can produce `eq` or `heartbeat`.
  `/media:now` now injects `media.sh bar`, which renders through the same
  builder as the statusline segment, so the two agree by construction and
  future presets need no skill change.

### Changed

- The style picker in `/media:statusline` offers the new `heartbeat` and
  `monitor`.
- `docs/statusline.md` said 29 progress-bar charsets; it and the README now
  say 31. The README also still described the waveforms as length-adaptive
  and fill-to-boundary, which 0.32.0–0.34.0 changed.

## [0.34.0] — 2026-07-14

### Changed

- **`pulse` and `ekg` redraw as a real ECG trace.** Both now render the
  heartbeat as an ECG lead — a flat isoelectric baseline, a narrow
  spike-tall QRS complex, then a low rounded T wave a beat later — instead
  of the former single triangular blip. `ekg` gains its own braille-tuned
  shape: the baseline holds one sub-dot so the isoelectric line stays
  visible, and the QRS packs into a needle barely a cell wide. **This
  changes how `pulse` and `ekg` look.** The `/media:now` bar spec, the
  style galleries, and the demo GIFs follow the new rendering.
- **The style gallery keeps each waveform beside its braille twin.**
  `swell`, `bars`, and `ekg` — the braille twins of `wave`, `eq`, and
  `pulse` — now sit with their block originals under Animated presets, and
  the Audio visualizers section lists only the spectrum-analyzer presets
  `spectrum`/`mirror`/`cava`/`ripple`.

## [0.33.0] — 2026-07-14

### Changed

- **`notes` joins the whole-bar visualizers.** The last fill-to-boundary
  preset now draws its ♪♫ note density across the full bar width like every
  other waveform and visualizer: with `statusline.color` on, the accent/dim
  split marks progress, and with it off the unplayed tail drops to `·`
  rests so progress still reads by density. **This changes how `notes`
  looks** — there is no flag to restore the boundary fill. The `/media:now`
  bar spec, the style galleries, and the Lo-fi recipe GIF follow the new
  rendering.

## [0.32.0] — 2026-07-14

### Changed

- **`wave`, `pulse`, `eq` and their braille twins `swell`, `bars`, `ekg` are
  now whole-bar visualizers.** Like `spectrum`/`mirror`/`cava`/`ripple`, the
  six presets draw across the full bar width instead of stopping at the
  played-position boundary: with `statusline.color` on, the accent/dim split
  marks progress, and with it off the unplayed tail is dimmed in height so
  progress still reads by shape. `notes` keeps its fill-to-boundary
  behavior. **This changes how the six presets look** — there is no flag to
  restore the boundary fill. The `/media:now` bar spec, the style galleries,
  and the demo/recipe GIFs follow the new rendering.

## [0.31.1] — 2026-07-14

### Fixed

- **`/media:now` draws the 0.31.0 bar presets.** The skill's bar spec still
  described the pre-0.31.0 fixed-glyph `wave`/`pulse`/`eq`/`notes` and did
  not know the seven visualizer presets, so the `/media:now` bar could
  contradict the statusline. It now mirrors the length-adaptive shapes and
  the whole-bar visualizers (unplayed tail flattened to ~30% height).

## [0.31.0] — 2026-07-14

### Added

- **Audio-visualizer progress-bar presets.** Seven new
  `style.progressbar.style` values turn the bar into a music visualizer:
  `spectrum` (independent bass-weighted bars) and `mirror` (a wave mirrored
  from the centre) in eighth-block heights, plus braille twins with double
  horizontal density — `cava` (spectrum), `ripple` (mirror), and
  `swell`/`bars`/`ekg` (braille `wave`/`eq`/`pulse`).
  `spectrum`/`mirror`/`cava`/`ripple` span the whole bar; with
  `statusline.color` on the accent/dim split marks progress, and with it off
  the unplayed tail is dimmed in height so progress still reads.

### Changed

- **`wave`, `pulse`, `eq`, and `notes` are now length-adaptive waveforms.**
  Instead of repeating a fixed handful of glyphs, each is computed from the
  bar width and drawn across eight block levels (`▁`..`█`), so a longer bar
  shows a bigger, smoother shape: `wave` a sine swell, `pulse` an ECG
  impulse, `eq` a multi-frequency equalizer, `notes` a `♪♫` density. They
  scroll sub-cell while playing and freeze on pause. **This changes how the
  four presets look** — there is no flag to restore the old fixed pattern.

## [0.30.0] — 2026-07-14

### Changed

- **The 0.28.0–0.29.0 click overhaul is rolled back to the 0.27.0
  dispatch.** The machinery those releases grew around the ⌘+click tab
  jump — the JXA jump helper (`focus-tab.js`) behind the Chromium
  browsers, the handler applet that waited on the click for TCC
  attribution, ChatGPT Atlas engine scripting, the per-dispatch applet
  self-heal (0.28.1), and the renderer's applet-format link gate with its
  background rebuild kick (0.29.0) — is removed. The applet hands a click
  to its handler in the background and quits, links render whenever the
  handler app exists, and Chrome, Edge, Brave, Vivaldi, Opera, and
  ChatGPT Atlas return to the pre-0.28 click: the playing app comes to
  the front. The applet rebuilds itself on the next session start
  (`APPLET_FORMAT` 4, same bundle id — an Automation approval you already
  gave carries over). Updating while older sessions stay open can flip
  the applet between formats again (the 0.28.1 flip-flop); it settles for
  good once those sessions close.
- **Kept: clicks stay on the `claude-media-control://` scheme.** The
  0.29.0 rename does not roll back — the Claude Desktop app still
  declares `claude-media` as an internal Electron scheme, so the links,
  the applet, and `open-url` keep using the plugin's own name. The applet
  still claims the legacy scheme and `open-url` still accepts it, so
  links rendered by still-open pre-0.29 sessions keep working.
- **Kept: the jump finds the player even while the tab title lags — now
  in Safari's tab jump.** Web players update `document.title` lazily in
  background-throttled tabs, so when no Safari tab name contains the
  track, the jump falls back to the first tab on a dedicated player site
  (music.youtube.com, open.spotify.com, music.apple.com, soundcloud.com,
  tidal.com, deezer.com). Titles and URLs are read locally, only to
  locate the player. (0.28.0 shipped this fallback inside the Chromium
  JXA helper; with that helper gone, the Safari branch carries it.)

## [0.29.0] — 2026-07-13

### Changed

- **Statusline clicks moved to the `claude-media-control://` scheme.**
  The Claude Desktop app declares `claude-media` as one of its internal
  Electron schemes, so a future version could claim the system-wide URL
  binding out from under the plugin — and ⌘+clicks would open the Claude
  app instead of controlling playback. The links, the handler applet, and
  `open-url` now use the plugin's own name as the scheme. The applet
  still claims the old scheme and `open-url` still accepts it, so links
  rendered by still-open pre-0.29 sessions keep working; the applet
  rebuilds itself automatically (`APPLET_FORMAT` 3) with the same bundle
  id, so the Automation approval you already gave carries over — no new
  consent dialog.
- **Links pause instead of going dead while the applet is stale.** Right
  after a plugin update — or after a still-open older session's warmup
  rebuilds the old applet (the v0.28.1 flip-flop) — the old applet
  doesn't claim the scheme the new links use, and a dead link can't
  trigger the click-time self-heal. The statusline now renders those
  ticks without links and rebuilds the applet in the background; links
  return a tick or two later, no click or new session needed.

## [0.28.1] — 2026-07-13

### Fixed

- **Clicks self-heal the handler applet.** Updating the plugin while
  older Claude Code sessions stay open leaves those sessions re-running
  *their* bundled installer on warmup — rebuilding the click applet back
  to the pre-0.28.0 format whose backgrounded handler breaks Automation
  attribution: clicks activate the app but the tab jump silently dies
  (measured live: a 0.27.0 warmup downgraded the applet 48 minutes after
  the 0.28.0 update). `open-url` now re-ensures the applet before
  dispatching, so the first click after any downgrade repairs it and the
  next one jumps again; the flip-flop ends for good once every
  pre-update session is closed.

## [0.28.0] — 2026-07-13

### Fixed

- **The ⌘+click tab jump actually reaches the tab now.** Since it shipped
  (v0.18.0), the Chromium side of the jump compiled its AppleScript
  against a bundle id held in a variable — and AppleScript resolves
  terminology like `active tab index` at compile time, so the script died
  with a syntax error (-2740) on every single click, and the silent
  best-effort swallow made that look like plain activation was all there
  was. Chrome, Edge, Brave, Vivaldi, and Opera clicks never got past
  bringing the app forward. The branch is now JXA
  (`scripts/focus-tab.js`), which resolves terminology at run time: same
  window+tab title match, same one-time Automation consent, and a hung
  browser is cut off after 30 s — long enough that the watchdog never
  tears down the consent dialog mid-answer. (Safari and Music compile
  against a fixed dictionary, so their scripts always ran — but read on.)
- **The first tab-jump completes when you approve the consent.** The
  click applet used to background the handler and quit immediately, so
  the jump's AppleEvent — the send that pops the one-time Automation
  dialog — raced its own timeout with its responsible process
  (`ClaudeMediaClick.app`) already gone: the send was cut down before
  anyone could realistically answer, the approval landed on a dead
  click, and the jump never happened even once the grant was recorded.
  The applet now waits for the handler (wrapped in `try`, so a refused
  click can't raise its error dialog): the dialog is attributed to a
  live applet, and the first click jumps the moment you hit Allow. The
  applet is rebuilt automatically on update (`APPLET_FORMAT` 2).

### Added

- **ChatGPT Atlas: the track click lands on the playing tab.** Atlas was
  listed as having no scripting interface — true of its native shell
  (`com.openai.atlas`), but the embedded Chromium engine
  (`com.openai.atlas.web`, the very bundle that plays the media) ships
  the full Chromium AppleScript suite. A title/artist ⌘+click now
  activates the shell and scripts the engine, selecting the window+tab
  that plays the track. First use asks the usual one-time Automation
  consent for `ClaudeMediaClick.app`; Spotify remains activation-only
  (nothing scriptable to land on).
- **The jump finds the player even while the tab title lags.** Web
  players update `document.title` lazily in background-throttled tabs —
  YouTube Music can sit on a bare "YouTube Music" for minutes after a
  track change — so when no tab title contains the track, the jump now
  falls back to the first tab on a dedicated player site
  (music.youtube.com, open.spotify.com, music.apple.com, soundcloud.com,
  tidal.com, deezer.com). Titles and URLs are read locally, only to
  locate the player.

## [0.27.0] — 2026-07-12

### Added

- **A recipes gallery — [`docs/recipes.md`](docs/recipes.md)** (English,
  한국어, 日本語, 简体中文): twelve ready-to-paste looks, each grounded
  in something recognizable — a green-phosphor CRT, a cassette deck, a
  backlit tuner dial, a VFD hi-fi panel, a mixing console, amber
  night-drive gauges, synthwave neon, lo-fi pastels, and more. Every
  recipe ships a GIF captured from the real statusline renderer (a 10 s
  loop with playing and paused frames), the exact `/media:config` block
  — every line validated through the real CLI — and a plain-text
  preview, with one fictional track playing throughout. The old
  four-recipe section in the style galleries points there now, and the
  `twilight` recipe closes with a named-color swap for terminals
  without truecolor.

## [0.26.0] — 2026-07-12

### Changed

- **`dash` reads like `smooth` now: a dashed track whose boundary
  thickens and fuses.** The empty side becomes a dashed `╌` track —
  the preset finally looks dashed at rest — and the boundary cell
  walks `╍ ┅ ┉` in quarters: the dashes thicken, multiply, and fuse
  into the `━` fill. The old sevenths ramp spent half its steps on
  light dashes (`╌ ┄ ┈`) that all but vanished against the `─` track,
  so the boundary looked stalled, then lurched; now ink only ever
  grows and every step is visibly distinct, so the boundary cell
  fills as continuously as `smooth`'s. The volume `progress` shape
  and the `/media:now` bar follow along, as always.

## [0.25.0] — 2026-07-12

### Changed

- **`playhead` accent stops at `╼`.** In the straddling state the `╾`
  half sits in the next cell — still remaining time — so it now dims
  with the track instead of taking the accent: the color boundary
  lands exactly on the progress boundary.
- **`dash` reworked: a light track and a six-step boundary.** The fill
  is `━` over a plain `─` track now, and the boundary cell walks
  `╌ ┄ ┈ ╍ ┅ ┉` in sevenths — the light line cracks into ever finer
  dashes, then thickens back into the solid line. Every step adds
  ink, so the boundary moves as continuously as `smooth`. This folds
  the old `seam` crack into `dash` and finally puts the heavy dashes
  to use.

### Removed

- **The `seam` preset.** Its light-line crack lives on as the first
  half of the new `dash` boundary; a stored
  `style.progressbar.style seam` falls back to `line`. Set `dash` for
  the successor.

## [0.24.0] — 2026-07-12

### Added

- **`playhead` bar preset.** `style.progressbar.style playhead` draws no
  fill at all: the track stays a thin `─` line end to end while a
  one-cell thick head glides along it in half-cell steps — parked on a
  cell it renders `━`, straddling two cells it splits into `╼╾`
  (`─────╼╾────────`). The elapsed side keeps the playing/paused accent
  so progress still reads at a glance, the head never leaves the track
  (0:00 parks it on the first cell, the end on the last), and — like
  every preset — the volume bar's `progress` shape and the `/media:now`
  bar follow along, every cell still ⌘+click-seekable.

## [0.23.0] — 2026-07-12

### Added

- **Seven sub-cell boundary presets.** `style.progressbar.style` gains
  `fade` (`███▓░░` — the boundary cell darkens through `▒▓`), `corner`
  (`███▙░░` — it fills by quadrants `▖▌▙`), `glide` (`━━━╾──` — the
  `line` bar advancing in half-cell steps), `stipple` (`⣿⣿⣷⣀⣀` — the
  `braille` bar with its dots rising `⣄⣤⣦⣶⣷`), `tiles` (`■■◧□□` —
  squares with a half-filled boundary), `dash` (`━━╌┈┈` — a heavy line
  fusing out of its thin-dash track `┈→┄╌→━`), and `seam` (`━━╌──` —
  the `line` bar cracking through the thin dashes `┈┄╌`). Like
  `smooth` and `rise`, the boundary cell renders the remainder as a
  partial glyph — fade/dash in thirds, corner/seam in quarters,
  stipple in sixths, glide/tiles in
  halves — so short tracks progress visibly between seconds. The volume
  bar's `progress` shape and the `/media:now` bar follow along, and
  with links on every cell stays ⌘+click-seekable.

## [0.22.0] — 2026-07-12

### Added

- **Hex colors in style specs.** Every color slot that took a named color
  (`style.track.title`, `style.progressbar.playing`, …) now also accepts
  an exact hex code — `#ff8800`, or the short `#f80` (stored canonically
  as lowercase `#rrggbb`) — rendered as 24-bit truecolor SGR. Set it like
  any other color, quoted so the shell doesn't read `#` as a comment:
  `/media:config style.track.title "bold #ff8800"`. Named colors still
  follow your terminal palette; hex needs a truecolor-capable terminal
  (iTerm2, Ghostty, WezTerm, Kitty, VS Code — Apple Terminal is not one).

## [0.21.0] — 2026-07-12

### Added

- **New progress-bar preset `rise`** — each cell fills bottom-up in ⅛
  steps: the boundary cell climbs ▁▂▃▄▅▆▇ and completes to █ over `░`
  water (`███▆░░░░░░` at 37%). The vertical sibling of `smooth` (which
  fills left-to-right), so short tracks progress visibly between
  seconds; the volume mini bar (`style.volume.style progress`) draws
  with it automatically. Set it with
  `/media:config style.progressbar.style rise` or through
  `/media:statusline`.

### Changed

- **Every volume bar shape now resolves eight real steps.** `stairs`
  climbs a `▁▂▃▄▅▆▇█` staircase (ceil(v×8/100) glyphs, 45% → `▁▂▃▄`)
  instead of the old `▂▄▆█` quarters, and the `progress` mini bar grew
  from five to eight cells — one cell per step, the same granularity
  the one-cell `block` shape always had. Both now span up to eight
  cells at full volume.

### Removed

- **The active-tab statusline gate is gone.** 0.19.0 made the segment
  update only in the terminal tab in use and freeze everywhere else;
  that behavior, its `statusline.activetab` config key, the tty-ancestry
  detection, and the per-terminal freeze snapshots are all removed — the
  segment simply updates in every session again, and the demo GIFs drop
  their two-tab scene. Stale `statusline.tty` / `statusline.frozen.*`
  files left in the plugin data dir by 0.19–0.20 are inert; delete them
  if you like.

## [0.20.0] — 2026-07-11

### Added

- **The progress bar length is configurable** — new style key
  `style.progressbar.length`, any whole number of cells from 1 to 60.
  One length drives both bars: the statusline segment and the
  `/media:now` reply draw with the same characters and the same width,
  so the two always match. With cmd+click links on, the seek map
  re-divides over the chosen cells — a longer bar simply seeks in finer
  steps. The five-cell volume mini bar is deliberately compact and
  keeps its size. Set the key directly
  (`/media:config style.progressbar.length 30`), through the
  `/media:statusline` styling flow, or just say it ("make the bar
  shorter"). Junk values in a hand-edited config fall back to the
  default instead of breaking the render.

### Changed

- **The default bar is twice as wide: 20 cells, up from 10.** The
  statusline bar now matches the `/media:now` bar (which was already
  20 characters), and the docs, the style gallery examples, and
  `docs/styles.gif` are redrawn at the new width.
  `style.progressbar.length 10` restores the pre-0.20 compact bar.

## [0.19.0] — 2026-07-11

### Added

- **The statusline segment updates only in the session you're using.**
  With several Claude Code sessions open, every one used to tick the
  now-playing line once a second; now only the session whose terminal
  last consumed input updates live — typing, scrolling, or simply
  focusing its tab (Claude Code enables terminal focus reporting, so a
  tab switch alone moves it). The other sessions keep the segment's last
  line, frozen — the bar and elapsed time stop moving, no per-tick read
  work happens there — and catch up within a tick or two of the tab being
  used again. Detection walks the statusline process's ancestry to the
  Claude Code process owning the session tty (statusline commands
  themselves run detached) and compares terminal last-input times (`w`'s
  IDLE signal) through a tiny state file whose mtime doubles as the
  holder's heartbeat, so a closed session forfeits the live segment
  within seconds; each live render drops the per-terminal freeze
  snapshot the inactive session reprints. Only the plugin's segment is
  gated — a pre-existing statusline keeps running live in every session,
  untouched. Sessions without a tty of their own (VS Code, the desktop
  app, headless runs) always update, and every gate failure fails open
  (live, never frozen). New config key **`statusline.activetab`**
  (default `on`); `off` = every session updates.

### Fixed

- **History no longer corrupts or duplicates entries when the title lags
  an artist change** — the reverse of the 0.18.0 fix. A track change can
  also surface artist-first: the transitional snapshot pairs the OLD title
  with the NEW artist, and the 0.18.0 amend then *overwrote the previous
  real entry* with that mix (same title + different artist looked like an
  artist correction). The title-first amend now requires evidence the
  artist was junk — borrowed from the entry before, or empty (a partial
  snapshot) — and the artist-first mix is repaired one read later by a
  sandwich rule: an entry sharing its title with its predecessor and its
  artist with the corrected read is superseded in place. Same 10-second
  window, same no-self-polling design.

## [0.18.0] — 2026-07-11

### Changed

- **Clicking the track lands on the media, not just the app.** The
  statusline's title/artist ⌘+click now resolves the owning app, brings it
  forward, and then — where the app allows it — moves its UI to the media
  itself: the browser window+tab whose title matches the track is selected
  (Safari and the AppleScript-capable Chromium family: Chrome, Edge,
  Brave, Vivaldi, Opera), and Music reveals the current track. Apps
  without a scripting interface (e.g. ChatGPT Atlas, Spotify) keep plain
  activation. Only known-scriptable bundles are ever scripted, so no
  Automation consent is triggered for apps that could not honor it; the
  first tab-jump asks a one-time consent for `ClaudeMediaClick.app`, and a
  denial (or any script error) silently keeps activation-only behavior.

## [0.17.0] — 2026-07-11

### Added

- **The statusline is cmd+clickable.** In hyperlink-capable terminals
  (iTerm2, Ghostty, WezTerm, Kitty, VS Code, Alacritty ≥ 0.11) the
  segment's parts are OSC 8 links: the **▶︎/⏸ icon toggles playback**, the
  **title/artist (and app name) bring the playing app to the front** —
  browser helpers resolve to their owning app (`com.openai.atlas.web` →
  ChatGPT Atlas) — and **every progress-bar cell seeks to its position**
  (10 cells → 5%, 15%, … 95%). Clicks land in a tiny local
  `claude-media://` handler app (`ClaudeMediaClick.app`, generated into the
  plugin data dir with macOS's bundled `osacompile`, no Dock icon, ad-hoc
  signed, registered via `lsregister` — zero third-party code) that
  dispatches to the new `media.sh open-url`, whose whole surface is three
  benign actions: `toggle`, `activate`, `seek/<percent>`. The handler is
  built when the statusline is wired (and on session start for installs
  wired before 0.17.0), refreshed on plugin updates, and unregistered +
  removed by `statusline uninstall` and the plugin-uninstall self-heal.
  New config key **`statusline.links`** (default `on`): `off` renders the
  segment plain; enabling rebuilds the handler and is refused (exit 3,
  fail-closed) when the build fails. Links render only while the handler
  app exists, are independent of `statusline.color`/`NO_COLOR`, and
  unsupported terminals simply ignore them. `/media:doctor` gained a
  `Click links` line.
- Playback commands and seeks now drop the statusline cache, so the
  segment shows the new state on the next tick (≤ 1s) instead of after the
  TTL — clicked or typed alike.

### Fixed

- **History no longer logs a phantom track when the artist lags a title
  change.** MediaRemote publishes a track change in stages — the title
  switches first, the artist follows a beat later — so a read landing
  mid-transition logged "next title — previous artist" as its own track.
  The corrected snapshot (same title, same app, different artist, within
  10 seconds) now **replaces** the transitional entry in place instead of
  appending. Same-title plays further apart, or from a different app,
  still append as before.
- Transitional snapshots with an **empty title** (browsers publish them
  mid-navigation) are no longer logged into the history.

## [0.16.0] — 2026-07-11

### Added

- **`pulse` progress-bar preset — an ECG trace.** `▂▂█▁▄` (baseline, R
  spike, S dip, T bump) repeats across the filled cells over dim `▁`, and
  the beat rolls toward the empty end each second while playing — a heart
  monitor for the track (`/media:config style.progressbar.style pulse`).
- **Nine more progress-bar presets.** Rolling, like `wave`/`pulse`: `eq`
  `▂▇▃█▅▆` equalizer bars and `notes` `♪♫` marching over `·`. Static
  pairs: `braille` `⣿`/`⣀`, `chevron` `▸`/`▹`, `tape` `▰`/`▱`,
  `cassette` `▮`/`▯`, and pure-ASCII `retro` `=`/`-`. Two new bar
  mechanisms: `knob` caps the fill with a `●` slider head (`━━━●────`),
  and `smooth` sizes its boundary cell as a ⅛-step partial block
  (`███▊░░░`) for sub-cell progress. Every preset drives the volume bar's
  `progress` shape and the `/media:now` bar too, so the surfaces always
  match.

### Changed

- **The `wave` progress-bar preset actually waves now.** The old `~~~~----`
  becomes a swell of block heights — `▂▄▆▄` repeating over calm dim `▁`
  water — phased by the playback position, so the wave rolls forward each
  second while playing and freezes on pause. The `/media:now` bar and the
  volume bar's `progress` shape draw with the same charset, as before;
  custom two-glyph charsets and the other presets are unchanged.

## [0.15.0] — 2026-07-10

### Added

- **Enabling the statusline now applies immediately — the plugin wires
  itself into `~/.claude/settings.json`.** `config display.statusline on`
  (the `/media:config` toggle, or saving an arrangement in
  `/media:statusline`) snapshots your current `"statusLine"` value into
  `~/.claude/statusline-media.backup.json`, generates a wrapper at
  `~/.claude/statusline-media.sh` that runs your previous statusline first
  (byte-for-byte) and appends the segment, and points `settings.json` at
  it — preserving your other statusLine keys (e.g. `padding`) and adding
  `refreshInterval: 1` unless you already set one. The segment shows up on
  the next statusline tick; the manual wrapper recipe is no longer needed
  (it remains supported for custom setups, which are detected and never
  touched).
- **Uninstalling the plugin reverts the statusline wiring by itself.**
  Claude Code has no plugin-uninstall hook, so the generated wrapper is
  self-healing: each tick it checks the installed-plugins registry (the
  plugin cache directory is swept lazily and proves nothing), and once the
  plugin is gone it restores the backed-up `statusLine` into
  `settings.json` and deletes itself and the backup — settings return to
  their exact pre-install state within a second of the uninstall. While
  the plugin is merely disabled, the wrapper renders nothing and keeps the
  wiring.
- **`media.sh statusline install | uninstall | status`.** `install` wires
  (idempotent; refreshes a managed wrapper in place), `uninstall` restores
  the backup, removes the wrapper + backup and turns `display.statusline`
  off, `status` reports the wiring state (`managed`, `manual`, `none`).
  `doctor` gained a `[8] Statusline` wiring line, and the session-start
  warm-up refreshes a managed wrapper after plugin updates.

### Changed

- `config display.statusline off` keeps the wiring (the segment just prints
  nothing, as before), so re-enabling is instant; unwiring is the new
  `statusline uninstall`.
- Docs: `docs/statusline.md` is restructured around the automatic setup
  (what exactly is written, the backup/restore guarantees, and the manual
  recipe kept as a custom-setup appendix); the README statusline and
  uninstall sections follow — in all four languages.

## [0.14.0] — 2026-07-10

### Changed

- **The volume bar draws in the progress bar's playing/paused colors.** The
  segment now has one accent everywhere: the ▶︎/⏸ icon, the progress-bar
  fill, and the volume bar (every shape — `block`, `progress`, `stairs`) all
  follow `style.progressbar.playing` / `.paused`. Previously the volume bar
  carried its own spec (`dim` by default).
- **`style.volume.bar` is now an on/off toggle** (default `on`) that only
  shows or hides the bar — with the color coming from the accent, there is
  no spec left to set. A value stored by an earlier version (e.g. `dim`,
  `cyan`) keeps the bar visible (treated as `on`), so nothing breaks on
  upgrade.

## [0.13.0] — 2026-07-10

### Added

- **Hide any part with `off`.** The eight text-part style keys
  (`style.track.title`, `style.track.artist`, `style.app`,
  `style.volume.bar`, `style.volume.percent`, `style.time.elapsed`,
  `style.time.total`, `style.output`) accept the value `off`, which hides
  just that part. Hiding follows the part: a hidden title takes the `—`
  separator with it, a hidden elapsed time drops the `/` before the total,
  and an item whose parts are all hidden disappears entirely (together with
  an explicit line it sat alone on). `off` changes content, not styling, so
  it applies even with colors off.
- **Output device icon key.** `style.output.icon` — `auto` (by device kind,
  the default), `none` (hidden), or any glyph. The output icon and device
  name are now controlled independently.
- **Volume bar shapes.** `style.volume.style` — `block` (the level-height
  `▄` bar, default), `progress` (a five-cell mini bar drawn with the
  progress-bar characters, so the two bars always match), or `stairs`
  (`▂▄▆█` steps).
- **`config statusline reset`.** One command restores the statusline's stock
  look: arrangement, explicit lines, the color/marquee toggles, and every
  `style.*` key. The `display.statusline` visibility toggle and the
  non-statusline features are untouched. Also offered as "Reset statusline
  settings" inside `/media:config`.

### Changed

- **`/media:statusline` is now the single statusline hub.** One three-tab
  interactive setup: **Items** (volume / progress bar / time / output device
  on/off), **Layout** (Standard / Stacked or a numeric pattern like
  `123/456`, digit legend included), and **Style** (pick an item group —
  track & app, volume, progress bar & time, output device — then a short
  per-part wizard with Keep / Default / Off / type-a-spec answers). Style
  wishes in plain words ("make the title cyan", "hide the artist") route
  here too.
- **`/media:config` slimmed down to quick settings.** One question, four
  options: statusline on/off, `/media:now` progress bar on/off, playback
  history on/off, and the statusline reset. Arrangement and styling moved to
  `/media:statusline`; every `config <key>` text command is unchanged.
- With colors on, the output token wraps only the device name in SGR
  (`🔊 \e[2mName\e[0m`, previously the icon was inside the wrap too) so the
  icon can be swapped or hidden independently — visually identical, and
  plain-text output is unchanged.

### Removed

- **The `/media:style` skill** — absorbed into `/media:statusline` (the
  Style tab, plus the same natural-language wishes). The `media.sh config
  style*` commands it drove are unchanged, so scripts and saved styles keep
  working.

## [0.12.0] — 2026-07-10

### Changed

- **The default progress-bar characters are now `line`** (`━━━━━━────`,
  previously `blocks` `██████░░░░`). Anyone who already set
  `style.progressbar.style` explicitly is unaffected; to keep the old look,
  run `/media:config style.progressbar.style blocks`.
- **The `/media:now` progress bar follows `style.progressbar.style`.** It
  was fixed to `█`/`░` before, so a restyled statusline bar and the chat
  reply could disagree; now both surfaces always draw with the same
  characters.
- Docs: the README statusline section is restructured into scannable
  bullets with a sample segment, and the statusline guides are tightened —
  in all four languages. Demo GIFs re-recorded with the new default bar.

## [0.11.0] — 2026-07-10

### Added

- **Per-item statusline styles.** Every visible part of the segment now has
  a string-valued `style.*` config key: `style.track.title` (`bold`) and
  `style.track.artist` (`italic`), `style.app` (`dim`), `style.time.elapsed`
  (`bold`) and `style.time.total` (`dim`), `style.volume.bar` /
  `style.volume.percent` (`dim`), and `style.output` (`dim`). A value is any
  of `bold dim italic underline` plus at most one color (`black red green
  yellow blue magenta cyan white` or `bright-<color>`) — or `none` for no
  styling. Specs render only while `statusline.color` is on; `NO_COLOR`
  still wins. The defaults reproduce the previous rendering exactly.
- **Progress-bar colors and characters.** `style.progressbar.playing` /
  `style.progressbar.paused` (defaults `green` / `yellow`) color the bar
  fill *and* the ▶︎/⏸ accent in front of the title — one accent, consistent
  across the segment. `style.progressbar.style` picks the bar characters:
  `blocks` `██████░░░░` (default), `wave` `~~~~~~----`, `line` `━━━━━━────`,
  `dots` `●●●●●●○○○○`, or any two characters meaning "filled + empty"
  (`"#-"` → `######----`). Character choices apply even with colors off.
- **Volume icon override.** `style.volume.icon` is `auto` (the level-tiered
  🔈/🔉/🔊, default), `none` (hidden), or any glyph (e.g. `♪`); muted always
  shows 🔇.
- **A `/media:style` skill.** Say what you want ("title bold cyan", "bar
  style wave", "볼륨 아이콘 ♪") and it maps the wish onto the keys; with no
  arguments it lists the current styles and takes the wish from the chat.
  Direct access: `media.sh config style` lists every key with its default,
  `config style.<part> "<spec>"` sets one, the value `reset` restores one
  key's default, and `config style reset` restores them all. Every style
  write drops the segment cache, so changes show on the next tick.

### Changed

- **The volume token styles its bar and percent separately** (previously one
  dim wrap around the whole token). With colors on, the SGR structure
  changes from `\e[2m🔉 ▄ 45%\e[0m` to `🔉 \e[2m▄\e[0m \e[2m45%\e[0m` —
  visually identical, and plain-text output is unchanged; the muted glyph
  now renders unstyled. All other tokens are byte-identical to 0.10.0 when
  no style key is set.
- `media.sh config` (no arguments) appends the style-key table to its
  listing, `config <key> <value…>` accepts unquoted multi-word values, and
  `doctor` reports how many style keys are customized.

## [0.10.0] — 2026-07-10

### Added

- **A `volume` statusline item.** Renders as icon + level bar + percent:
  a speaker glyph tiered by level (🔈/🔉/🔊, 🔇 at zero), an eighth-block
  bar whose height tracks the level (50% = the half block `▄`), and the
  percent — `🔉 ▄ 45%`; muted collapses to `🔇`. The value rides the same
  native read as the rest of the segment (CoreAudio virtual main volume,
  a public API), so the item adds no extra process spawn per tick; like
  `output`, it needs the native helper. Setting the volume with
  `/media:volume` shows up on the next tick. In the classic grouped
  layout, `volume` joins an adjacent track group, and adjacent
  `output`+`volume` share a group.
- **Device-kind icons for the `output` item.** The icon now follows the
  device type (CoreAudio transport type, public API): `🎧` Bluetooth
  devices and the built-in headphone jack, `📺` HDMI/DisplayPort audio,
  `📶` AirPlay, `🔊` everything else.

### Changed

- **The presets include the volume item, in a new default order.**
  Standard = `track,app,volume,progressbar,time,output` on one line;
  Stacked = two explicit lines, `track,app,volume` /
  `progressbar,time,output`. Saved arrangements are untouched until you
  pick a preset again, and the engine's default field set
  (`track app progressbar time`) is unchanged.
- **Numeric-pattern digits follow the default order**: 1 track, 2 app,
  3 volume, 4 progress bar, 5 time, 6 output — so Standard is `123456`
  and Stacked is `123/456`.
- **`Custom…` takes the pattern straight from the chat input.** The
  picker no longer asks a second multiple-choice question (whose option
  hotkeys swallowed the digits you tried to type); it prints a digit
  legend — which number is which item, with a sample of each — plus your
  current arrangement as a pattern, and you type the new pattern (e.g.
  `123/456`) as a normal reply. In `/media:config`, the extra statusline
  items moved to their own "Items" question (Output device / Volume).

## [0.9.0] — 2026-07-10

### Added

- **Per-line statusline arrangements.** A `/` in `statusline.fields` starts
  a new line and switches the segment to the explicit layout: every line
  shows exactly the items placed on it, in that order — the grouping rules
  and `statusline.multiline` no longer apply, and a line with nothing to
  show right now (e.g. `output` without the native helper) disappears
  instead of leaving a blank. Within a line, `app` right after `track`
  still folds into it as `(App)`; anywhere else it renders as the plain app
  name. Lists without `/` render exactly as before.

  ```
  /media:config statusline.fields "track,app,/,progressbar,time,/,output"
  ```

  ```
  ▶︎ Karma Police — Radiohead (Spotify)
  ██████░░░░  2:13/4:24
  🔊 AirPods Pro
  ```

### Changed

- **The `/media:statusline` picker speaks numeric patterns.** The layout
  question offers two presets — Standard (`track,app,progressbar,time,output`
  on one line; it now includes the output device) and Stacked (three explicit
  lines: track + app / bar + time / output) — and `Custom…` asks for one
  compact pattern like `12/34/5`: digits name the items (1 track, 2 app,
  3 progress bar, 4 time, 5 output), `/` starts a new line, digit order is
  display order, and a digit you leave out hides that item. Patterns also
  work as arguments (`/media:statusline 125/34`). `Compact` still works as a
  typed preset and `Everything` stays as an alias of Standard; saved
  arrangements are untouched until you pick a new one.

## [0.8.0] — 2026-07-10

### Added

- **The output device can share the track's line in the stacked layout.**
  `output` now joins the track group when the two sit next to each other in
  the saved order — and an `app` folded into the track group no longer breaks
  that adjacency. So `statusline.fields "track,app,output,progressbar,time"`
  with `statusline.multiline on` renders as two lines:

  ```
  ▶︎ Karma Police — Radiohead (Spotify)  🔊 AirPods Pro
  ██████░░░░  2:13/4:24
  ```

  Previously `output` always formed a group of its own, so the stacked layout
  forced it onto a separate line. Nothing changes on one line (grouping is
  invisible there), and the presets keep `output` at the end — away from the
  track — so existing stacked arrangements render exactly as before.

## [0.7.0] — 2026-07-10

### Added

- **Custom arrangements inside the `/media:statusline` picker.** The
  no-argument picker is no longer preset-only: next to the preset previews
  (Standard / Everything / Compact) sits `Custom…`, which walks you through
  building your own arrangement — check exactly which items appear (app,
  progress bar, time, output device; the track is always in), then pick
  which item leads (track / time / progress bar / output first). A separate
  "One line or stacked?" question applies to any arrangement, so every
  combination can stack — stacking is no longer tied to the Stacked preset.
  Typed orders and natural-language requests ("time first") keep working
  exactly as before.

### Fixed

- **The statusline elapsed time was rendered dim and easy to miss.** The
  whole `2:13/4:24` token used the faint SGR style, which many terminal
  themes render barely readable — and `/media:now` bolds the elapsed time,
  so the two surfaces looked inconsistent. The elapsed part (the part that
  moves) is now bold like the track title; only the `/4:24` tail stays dim.
  With colors off (or `NO_COLOR`) the output is byte-identical to before.
- **`/media:now` and `/media:menu` could show a stale position.** Their
  reply templates never said which JSON field the elapsed `m:ss` comes
  from, so the rendering model could pick `elapsedTime` — the app's last
  snapshot, which for web players can lag minutes behind the real position
  (measured: a track playing 41 s reported `elapsedTime` 1:15 vs the true
  1:56) — while the statusline extrapolates via `elapsedTimeNow`. Both
  skills now name `elapsedTimeNow` explicitly, matching the statusline and
  `/media:seek`.

## [0.6.0] — 2026-07-10

### Removed

- **The audio spectrum, entirely** — `/media:spectrum`, the statusline
  `spectrum` item, `native/spectrum.m`, and the `display.spectrum` /
  `spectrum.style` / `spectrum.color` config keys.

  **Why:** the spectrum captured the system output mix with a Core Audio
  process tap, and every Claude Code session ran its own capture. With
  sessions open in several terminal tabs — a completely normal way to use
  Claude Code — the concurrent taps, each building its own aggregate device
  over the same output, conflicted and broke the Mac's audio session. A
  cosmetic visualization must never be able to disrupt the very audio it
  visualizes, and independent sessions have no reliable way to coordinate
  their captures, so the feature is removed rather than gated. This also
  retires the only feature that ever asked for the system-audio-recording
  permission — the plugin now requests no audio-capture permission at all
  (a previously granted one can be revoked in System Settings > Privacy &
  Security).

  Pre-0.6.0 configs stay valid: the removed keys are ignored, and a stored
  `spectrum` statusline item is filtered out on read.

### Added

- **`/media:statusline` — a statusline arrangement picker.** Pick a layout
  from **visual previews** shown next to the options (Standard / Stacked /
  Compact / Everything), or describe any arrangement ("time first", "output
  device in front", "one item per line") and it is mapped onto an ordered
  item list. The same preset picker (plus a "Keep current" option that
  previews your present arrangement) opens inside `/media:config`.
- **Statusline items now render in the order you save them.**
  `statusline.fields` keeps the order it is given — `/media:config
  statusline.fields "time,progressbar,track"` puts the time first. `app`
  still attaches to the track group, and the progress bar + time share a
  group (one line in the stacked layout) when adjacent.

### Changed

- The interactive `/media:config` flow was rebuilt around the layout picker:
  a single layout question with previews replaces the item checkboxes, the
  extras question (and its redundant `None` option — unchecking already means
  "none") is gone, and the output-device item became a checkbox among the
  statusline toggles. Feature toggles (statusline on/off, colors, marquee,
  `/media:now` progress bar, history) are unchanged.

## [0.5.0] — 2026-07-10

### Changed

- **`/media:config` is now interactive.** Running `/media:config` with no
  arguments opens an AskUserQuestion settings picker: check which now-playing
  items the statusline shows (track, app, progress bar, time, output device,
  spectrum), toggle every display feature on/off from radio-style menus
  (statusline segment, separate-line layout, colors, marquee, the
  `/media:now` progress bar, playback history), and pick the spectrum style and
  color. Each on/off setting is a checkbox — checked means on. The text form
  `/media:config <key> on|off` (and `statusline.fields`, `spectrum.style`,
  `spectrum.color`) still works for scripting and one-off changes, so the
  underlying `media.sh config` interface is unchanged.

### Removed

- **`/media:statusline`** — folded into `/media:config`. Everything it did
  (choosing which statusline items appear and their layout) is now part of the
  interactive `/media:config` flow, alongside the display toggles it never
  covered before. Run `/media:config` instead; the `media.sh statusline`
  subcommand that renders the segment is untouched.

## [0.4.0] — 2026-07-09

### Added

- **Playback history** (`/media:history`): a passive local log of played
  tracks. Entries are recorded on reads that happen anyway (statusline ticks,
  `/media:now`, playback re-reads) — no polling, no daemon, no extra resource
  cost. Newest-first listing (`history [count]`, `history --json`), `history
  clear`, a 500-entry cap on `history.jsonl`, and a `history.record` config
  key (default `on`) to stop logging.
- **Output devices** (`/media:output`): list the Mac's audio output devices
  and switch the default one by name, unique case-insensitive substring, or
  1-based list position. Implemented with the public CoreAudio API in the
  native adapter (`adapter_output_list` / `adapter_output_set`) — no extra
  permissions; degraded mode (no native helper) gets a clear refusal.
- Statusline `app` field, **in the default field set**: the playing app after
  the track, e.g. `▶︎ Karma Police — Radiohead (Spotify)`. Previously the app
  name was read but never rendered anywhere in the statusline.
- Statusline `output` field (opt-in via `/media:statusline`): the current
  audio output device (`🔊 AirPods Pro`). The adapter now includes
  `outputDevice` in the now-playing JSON, so the field rides the same read as
  the rest of the segment — no extra process per refresh.
- **Marquee scrolling** for long statusline titles (`statusline.marquee`,
  default `on`): titles wider than 30 display cells scroll through a fixed
  30-cell window, one character per second, in step with the 1-second segment
  cache. CJK characters count as two cells so the window width stays steady.

## [0.3.0] — 2026-07-09

### Added

- `statusline.color` config key (default `on`): the statusline segment is now
  ANSI-styled — state-colored icon and progress-bar fill (green playing /
  yellow paused), bold title, italic artist, dim time. Standard 16-color SGR
  codes only, so the terminal palette stays in charge; the `NO_COLOR`
  environment variable is honored, and `statusline.color off` restores plain
  text.
- `spectrum.style` + `spectrum.color` config keys for the spectrum bars:
  `solid` (default) tints every bar in one configurable color (`red green
  yellow blue magenta cyan white`, default `cyan`); `rainbow` applies a fixed
  front-to-back color cycle by bar position — never by loudness — that
  marches one step per second (`spectrum.color` is then ignored). The tint
  shows in the statusline segment and when `media.sh spectrum` runs directly
  in a terminal; piped/captured spectrum output stays plain.

### Changed

- Skill replies render as styled markdown instead of plain code-block text:
  `/media:now` shows a bold title, italic artist and a bold elapsed time;
  playback confirmations, `/media:menu` state lines, seek/volume replies and
  artwork captions follow the same format.

## [0.2.0] — 2026-07-09

### Added

- **Audio spectrum** (`/media:spectrum`, opt-in): a live frequency-bar view of
  the system output mix, captured with a Core Audio process tap
  (`native/spectrum.m`, public API since macOS 14.4) and analyzed by a local
  vDSP FFT. `snapshot` (one shot) or `--live <seconds>`. No audio is stored or
  transmitted — only the resulting bar string is printed.
- `display.spectrum` config key with a fail-closed enable: the tap is
  exercised, and if it captures only silence while audio is playing the enable
  is refused (the audio-recording grant is missing). Runtime revocation
  auto-disables the feature.
- **Customizable statusline** via `/media:statusline` (interactive): pick which
  items appear — track, progress bar, time, spectrum — with an AskUserQuestion
  picker (select all for everything).
- `statusline.multiline` config key: lay statusline items out on separate lines
  instead of one line.
- Progress bar and the mini spectrum are now available as statusline items.

### Changed

- Statusline segment TTL cut from 5s to 1s so the elapsed time and progress bar
  advance every second (a now-read costs ~60ms). Pair with a small
  `refreshInterval` for idle ticking (see `docs/statusline.md`).

### Fixed

- `json_field` now reads JSON booleans (e.g. `playing`), which the runtime
  permission-revocation downgrade and the spectrum preflight rely on.

### Notes

- The process tap needs a signed binary; clang applies an ad-hoc signature
  automatically on Apple Silicon, which suffices once the terminal app holds the
  "system audio recording" grant. macOS shows no automatic prompt for CLI
  tools, so the permission is granted manually in System Settings > Privacy &
  Security (`/media:doctor` and the skills explain this).
- The spectrum needs macOS 14.4+; on older systems the feature stays hidden and
  never compiles the helper.

## [0.1.0] — 2026-07-09

Initial public release.

### Added

- Initial MVP: system-wide now-playing **read and control** on macOS via a
  self-contained MediaRemote bridge (`native/adapter.m` + `native/loader.pl`),
  loaded through `/usr/bin/perl` to pass the macOS 15.4+ entitlement check.
  Ports BSD-3-Clause techniques from ungive/mediaremote-adapter (see
  `native/NOTICE`).
- Subcommands: `now`, `play`, `pause`, `toggle`, `next`, `prev`, `seek`,
  `test`, `config`, `doctor`, `detect`.
- Skills: `now`, `toggle`, `play`, `pause`, `next`, `prev`, `seek`, `menu`
  (interactive remote via AskUserQuestion), `artwork`, `volume`, `config`,
  `doctor`.
- Fallback chain: compile-free JXA read and per-app AppleScript control
  (Spotify / Apple Music) when the native helper is unavailable, with a
  `degraded` flag and doctor cross-checks.
- First-run native build cached under `${CLAUDE_PLUGIN_DATA}`, keyed on
  plugin version + macOS build + arch for automatic rebuilds after updates.
- Fail-closed display-feature config (`display.progressbar`,
  `display.statusline`) and a SessionStart detect hook.
- `artwork` — save the current track's cover art to a file and display it
  (native path only; the image never enters the conversation as base64).
- `volume` — read or set the system output volume (0–100).
- `statusline` — one-line now-playing segment backed by a 5s TTL cache, gated
  by the `display.statusline` config key. Recipe in `docs/statusline.md`
  (universal wrapper that preserves any existing statusline and appends
  now-playing as its own line).
- SessionStart async build warm-up, so the first media command has no
  first-run build delay.
- Unit tests (`tests/media.bats`, native stubbed out) and a macOS GitHub
  Actions CI: shellcheck, strict native build, load/symbol smoke test,
  `bats`, and `claude plugin validate --strict`.
- Documentation: full README (how it works, private-API disclaimer,
  requirements, verify, troubleshooting, complete-uninstall guarantee).
