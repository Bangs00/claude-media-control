# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning is
[SemVer](https://semver.org/spec/v2.0.0.html), tracked in
`.claude-plugin/plugin.json`.

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
