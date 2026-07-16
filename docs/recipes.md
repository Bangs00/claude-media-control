# Statusline recipes

**English** | [한국어](recipes.ko.md) | [日本語](recipes.ja.md) | [简体中文](recipes.zh-CN.md)

Ready-to-paste looks for the now-playing segment, each grounded in
something you would recognize — a phosphor terminal, a tape deck, a tuner
dial, a mixing console. Colors are derived from the thing itself: a
phosphor's emission line, a pigment, a documented standard. Every command
below went through the real `media.sh config` validation, and every GIF is
the renderer's own output at one frame per second (all with a fictional
track — *Rented Sunsets* by *Modem Chorus*, playing in a fictional app
called *Aux*).

To apply one: paste the block's lines to Claude one at a time, or hand it
the whole block and say "apply this". Changes land on the next statusline
tick — no restart.

Each recipe starts from the **stock look**. Coming from another recipe (or
your own tweaks), reset first — and the same command is the way back out:

```
/media:config statusline reset
```

(Key-by-key details live in the [style gallery](styles.md); the reset
family is under [Back to defaults](styles.md#back-to-defaults).)

Hex colors render as 24-bit truecolor — fine in most terminals, but not in
Apple Terminal; [Twilight](#twilight) ends with the named-color swap that
works for any recipe here.

## Zen

Just the title and where you are in it — marquee off, so nothing ever moves
but the clock.

![The Zen recipe rendered live at one frame per second](recipes/zen.gif)

```
/media:config statusline.fields "track,time"
/media:config style.track.artist off
/media:config style.time.total off
/media:config statusline.marquee off
```

```
▶︎ Rented Sunsets  1:32
```

## Mono

White on black with a thin line bar — the pocket-player OLED look, named
colors only.

![The Mono recipe rendered live at one frame per second](recipes/mono.gif)

```
/media:config statusline.fields "track,progressbar,time"
/media:config style.progressbar.playing bright-white
/media:config style.progressbar.paused bright-black
/media:config style.track.title "bold bright-white"
/media:config style.track.artist "italic bright-black"
/media:config style.time.elapsed "bold bright-white"
/media:config style.time.total "dim white"
```

```
▶︎ Rented Sunsets — Modem Chorus  ━━━━━━━─────────────  1:32/4:07
```

## Hardcopy

Pure ASCII and zero color, like a printed terminal log — for plain
terminals and `NO_COLOR` setups.

![The Hardcopy recipe rendered live at one frame per second](recipes/hardcopy.gif)

```
/media:config statusline.fields "track,progressbar,time"
/media:config style.progressbar.style retro
/media:config statusline.color off
/media:config statusline.marquee off
```

```
▶︎ Rented Sunsets — Modem Chorus  =======-------------  1:32/4:07
```

## Plasma

Orange cells on near-black — the neon gas panel, where a cell is lit or it
is not and there is nothing in between.

![The Plasma recipe rendered live at one frame per second](recipes/plasma.gif)

```
/media:config statusline.fields "track,progressbar,time"
/media:config style.progressbar.style blocks
/media:config style.progressbar.playing "#ff6a1a"
/media:config style.progressbar.paused "#a34410"
/media:config style.track.title "bold #ffcba3"
/media:config style.track.artist "italic #c26a2e"
/media:config style.time.elapsed "bold #ff6a1a"
/media:config style.time.total "dim #7a3a12"
```

```
▶︎ Rented Sunsets — Modem Chorus  ███████░░░░░░░░░░░░░  1:32/4:07
```

The orange is neon's own — its two strongest visible lines sit at 585 and
640 nm. Swap the bar for `rise`, `fade` or `corner` and the same fill grows
in eighths, thirds or quarters of a cell instead of whole ones; for the
dot-matrix version of the panel, use `braille` (or `stipple`, its
partial-cell twin).

## Phosphor

Green-on-black monochrome with a solid block bar — the green-phosphor CRT
terminal.

![The Phosphor recipe rendered live at one frame per second](recipes/phosphor.gif)

```
/media:config statusline.fields "track,progressbar,time"
/media:config style.progressbar.style "█ "
/media:config style.progressbar.playing "#33ff33"
/media:config style.progressbar.paused "#22aa22"
/media:config style.track.title "bold #33ff33"
/media:config style.track.artist "#22bb33"
/media:config style.time.elapsed "bold #33ff33"
/media:config style.time.total "dim #33ff33"
```

```
▶︎ Rented Sunsets — Modem Chorus  ███████               1:32/4:07
```

For the amber-phosphor cousin, swap `#33ff33`/`#22bb33`/`#22aa22` for
`#ffb000`/`#cc8400`/`#996300`.

## Goban

Slate black against clamshell white — Go stones, where the black stone is
cut a third of a millimetre larger so that the two read the same size.

![The Goban recipe rendered live at one frame per second](recipes/goban.gif)

```
/media:config statusline.fields "track,progressbar,time"
/media:config style.progressbar.style dots
/media:config style.progressbar.playing "#f7f3e8"
/media:config style.progressbar.paused "#8a8578"
/media:config style.track.title "bold #f7f3e8"
/media:config style.track.artist "italic #b5a882"
/media:config style.time.elapsed "bold #e8c88a"
/media:config style.time.total "dim #6b6455"
```

```
▶︎ Rented Sunsets — Modem Chorus  ●●●●●●●○○○○○○○○○○○○○  1:32/4:07
```

## Service

Gold stripes on wool — the sleeve chevron, which has meant exactly one
thing since 1777: time served.

![The Service recipe rendered live at one frame per second](recipes/service.gif)

```
/media:config statusline.fields "track,progressbar,time"
/media:config style.progressbar.style chevron
/media:config style.progressbar.playing "#c9a227"
/media:config style.progressbar.paused "#8a6f1e"
/media:config style.track.title "bold #e8d9a0"
/media:config style.track.artist "italic #9a8b5e"
/media:config style.time.elapsed "bold #c9a227"
/media:config style.time.total "dim #6b5a2c"
```

```
▶︎ Rented Sunsets — Modem Chorus  ▸▸▸▸▸▸▸▹▹▹▹▹▹▹▹▹▹▹▹▹  1:32/4:07
```

## Platform

White glaze closing on a half tile — station wall tile, glazed white
because white throws the light back at you underground.

![The Platform recipe rendered live at one frame per second](recipes/platform.gif)

```
/media:config statusline.fields "track,progressbar,time"
/media:config style.progressbar.style tiles
/media:config style.progressbar.playing "#f2efe6"
/media:config style.progressbar.paused "#1e3a34"
/media:config style.track.title "bold #fdfcf8"
/media:config style.track.artist "italic #8fa8a0"
/media:config style.time.elapsed "bold #f2efe6"
/media:config style.time.total "dim #5c6b66"
```

```
▶︎ Rented Sunsets — Modem Chorus  ■■■■■■■◧□□□□□□□□□□□□  1:32/4:07
```

The `◧` is not a compromise — a course of tile really does end in a half
tile, which is why the boundary cell has one to draw.

## Telegraph

Brass and varnished oak, with dots thickening into dashes at the boundary —
the telegraph's oldest rule, where a dash is three dots held together.

![The Telegraph recipe rendered live at one frame per second](recipes/telegraph.gif)

```
/media:config statusline.fields "track,progressbar,time"
/media:config style.progressbar.style dash
/media:config style.progressbar.playing "#b08d57"
/media:config style.progressbar.paused "#6e5327"
/media:config style.track.title "bold #efe6d0"
/media:config style.track.artist "italic #a1854f"
/media:config style.time.elapsed "bold #d4b06a"
/media:config style.time.total "dim #6e5327"
```

```
▶︎ Rented Sunsets — Modem Chorus  ━━━━━━━┅╌╌╌╌╌╌╌╌╌╌╌╌  1:32/4:07
```

## Cassette

A warm tape deck: the cassette-window bar, ♪ stair-step level,
cream-and-amber lettering.

![The Cassette recipe rendered live at one frame per second](recipes/cassette.gif)

```
/media:config statusline.fields "track,volume,progressbar,time"
/media:config style.progressbar.style cassette
/media:config style.progressbar.playing "#e8863a"
/media:config style.progressbar.paused "#c94f3d"
/media:config style.volume.style stairs
/media:config style.volume.icon ♪
/media:config style.volume.percent off
/media:config style.track.title "bold #f2e3c6"
/media:config style.track.artist "italic #d9a066"
/media:config style.time.elapsed "bold #f2e3c6"
/media:config style.time.total "dim #d9a066"
```

```
▶︎ Rented Sunsets — Modem Chorus  ♪ ▁▂▃  ▮▮▮▮▮▮▮▯▯▯▯▯▯▯▯▯▯▯▯▯  1:32/4:07
```

## Dial

A 40-cell hairline scale with a red needle — the backlit tuner dial of a
silver-face receiver, in ice-blue lettering.

![The Dial recipe rendered live at one frame per second](recipes/dial.gif)

```
/media:config statusline.fields "track,progressbar,time"
/media:config style.progressbar.style playhead
/media:config style.progressbar.length 40
/media:config style.progressbar.playing "#ff6b6b"
/media:config style.progressbar.paused "#e5c25b"
/media:config style.track.title "bold #a9d1ff"
/media:config style.track.artist "italic #6f9fd8"
/media:config style.time.elapsed "bold #a9d1ff"
/media:config style.time.total "dim #6f9fd8"
```

```
▶︎ Rented Sunsets — Modem Chorus  ──────────────╼╾────────────────────────  1:32/4:07
```

## Vernier

Hardened steel and a brass thumbwheel: a head sliding a hairline scale and
parking *between* the marks — which is what a vernier has been for since
1631.

![The Vernier recipe rendered live at one frame per second](recipes/vernier.gif)

```
/media:config statusline.fields "track,progressbar,time"
/media:config style.progressbar.style glide
/media:config style.progressbar.length 36
/media:config style.progressbar.playing "#dfe4e9"
/media:config style.progressbar.paused "#b08d57"
/media:config style.track.title "bold #eef2f5"
/media:config style.track.artist "italic #8d959e"
/media:config style.time.elapsed "bold #b9bec4"
/media:config style.time.total "dim #5c636a"
```

```
▶︎ Rented Sunsets — Modem Chorus  ━━━━━━━━━━━━━╾──────────────────────  1:32/4:07
```

Length 36, not 40: a `glide` head only splits into `╾` on the half-cells,
and at this position a 40-cell bar lands square on a boundary and never
shows one.

## VFD

Cyan-green segments on a dark ground — the vacuum-fluorescent front panel
of a 90s hi-fi, with the app name as its source label.

![The VFD recipe rendered live at one frame per second](recipes/vfd.gif)

```
/media:config statusline.fields "track,app,volume,progressbar,time"
/media:config style.progressbar.style tape
/media:config style.progressbar.playing "#3ef0c0"
/media:config style.progressbar.paused "#e8a33d"
/media:config style.volume.style progress
/media:config style.volume.icon none
/media:config style.volume.percent "dim #57d9c0"
/media:config style.track.title "bold #b8fff0"
/media:config style.track.artist "italic #57d9c0"
/media:config style.app "#2e9c88"
/media:config style.time.elapsed "bold #b8fff0"
/media:config style.time.total "dim #57d9c0"
```

```
▶︎ Rented Sunsets — Modem Chorus (Aux)  ▰▰▰▱▱▱▱▱ 35%  ▰▰▰▰▰▰▰▱▱▱▱▱▱▱▱▱▱▱▱▱  1:32/4:07
```

## Console

A mixing-desk split: meters and timecode on top, transport and monitors
below — LED green, record red.

![The Console recipe rendered live at one frame per second](recipes/console.gif)

```
/media:config statusline.fields "volume,progressbar,time,/,track,app,output"
/media:config style.progressbar.style eq
/media:config style.progressbar.playing green
/media:config style.progressbar.paused red
/media:config style.volume.style progress
/media:config style.time.elapsed "bold yellow"
/media:config style.output.icon 🎚
```

```
🔉 ▁▄▄▆▄▅▄▇ 35%  ▅▅▅▆▄▄▆▆▆▆▂▂▃▃▅▆▄▅▄▄  1:32/4:07
▶︎ Rented Sunsets — Modem Chorus (Aux)  🎚 Bookshelf Speakers
```

The volume mini-meter borrows the progress bar's `eq` characters and bounces
along with it.

## Slider wall

Cream, black and a red top end — the VU meter, a needle built to be slow on
purpose so that it shows you loudness instead of chasing every transient.

![The Slider wall recipe rendered live at one frame per second](recipes/slider-wall.gif)

```
/media:config statusline.fields "track,volume,progressbar,time"
/media:config style.progressbar.style bars
/media:config style.progressbar.playing "#f0e3c0"
/media:config style.progressbar.paused "#c44a3d"
/media:config style.volume.style stairs
/media:config style.volume.percent off
/media:config style.track.title "bold #f7efd9"
/media:config style.track.artist "italic #b9a887"
/media:config style.time.elapsed "bold #f0e3c0"
/media:config style.time.total "dim #7d7159"
```

```
▶︎ Rented Sunsets — Modem Chorus  🔉 ▁▂▃  ⣄⡀⢀⣤⣤⣴⣦⣄⣤⣶⣴⣶⣦⣀⣀⣀⣀⣴⣦⣤  1:32/4:07
```

`bars` builds its shape from a fundamental plus an inharmonic partial and a
sub — which is why it moves like programme material rather than like a
chord. For the block-height version, use `eq` (that is [Console](#console)).

## Third-octave

Red LED columns that dance in place rather than stretch — the third-octave
analyser, whose bands sit on fixed centres, so a wider bar buys you more
spectrum instead of a wider view of the same slice.

![The Third-octave recipe rendered live at one frame per second](recipes/third-octave.gif)

```
/media:config statusline.fields "track,progressbar,time"
/media:config style.progressbar.style spectrum
/media:config style.progressbar.playing "#ff2d10"
/media:config style.progressbar.paused "#8c1f0d"
/media:config style.track.title "bold #ffc2ae"
/media:config style.track.artist "italic #d4654a"
/media:config style.time.elapsed "bold #ff7a45"
/media:config style.time.total "dim #8a3f2a"
```

```
▶︎ Rented Sunsets — Modem Chorus  ▄▁▃▆▅▄▆▅▂▃▆▆▄▅▅▃▃▆▆▄  1:32/4:07
```

The red is the first visible LED's own — gallium arsenide phosphide, 655 nm,
1962. Swap `spectrum` for `cava` to draw the same analysis in braille dots
at twice the horizontal density.

## Seiche

The whole lake swaying in its bowl — a standing wave that fits the basin
whatever its width, which is why this bar shows the same two-and-a-half
waves at every length.

![The Seiche recipe rendered live at one frame per second](recipes/seiche.gif)

```
/media:config statusline.fields "track,progressbar,time"
/media:config style.progressbar.style wave
/media:config style.progressbar.playing "#3b8fc4"
/media:config style.progressbar.paused "#5f9e79"
/media:config style.track.title "bold #d6ecf5"
/media:config style.track.artist "italic #7fb3cc"
/media:config style.time.elapsed "bold #a5d5ea"
/media:config style.time.total "dim #4a7285"
```

```
▶︎ Rented Sunsets — Modem Chorus  █▇▅▂▁▂▄▇█▇▅▂▁▂▄▇█▇▅▂  1:32/4:07
```

Indigo to green is the direction the lake-colour scale runs — the man who
named the seiche made that scale too. Swap `wave` for `swell` for the
braille twin.

## Ripple tank

A lamp above, a tray of water below, a needle tapping the middle — the wave
casts its own shadow, out from the centre, in the apparatus built to prove
that light was a wave.

![The Ripple tank recipe rendered live at one frame per second](recipes/ripple-tank.gif)

```
/media:config statusline.fields "track,progressbar,time"
/media:config style.progressbar.style mirror
/media:config style.progressbar.playing "#f2ead4"
/media:config style.progressbar.paused "#8a94a6"
/media:config style.track.title "bold #fdfaf0"
/media:config style.track.artist "italic #9fb0c4"
/media:config style.time.elapsed "bold #e8dcbb"
/media:config style.time.total "dim #5c6675"
```

```
▶︎ Rented Sunsets — Modem Chorus  ▇▄▁▁▄▇█▆▃▁▁▃▆█▇▄▁▁▄▇  1:32/4:07
```

`ripple` is the braille twin of the same shape.

## Lead II

A trace at twenty-five millimetres a second, the paper speed the whole
world agreed on — which is why a longer bar gives you more beats and never
a wider one.

![The Lead II recipe rendered live at one frame per second](recipes/lead-ii.gif)

```
/media:config statusline.fields "track,progressbar,time"
/media:config style.progressbar.style heartbeat
/media:config style.progressbar.length 40
/media:config style.progressbar.playing "#55f5a1"
/media:config style.progressbar.paused "#6f8fa8"
/media:config style.track.title "bold #c9fdde"
/media:config style.track.artist "italic #3fbc7b"
/media:config style.time.elapsed "bold #55f5a1"
/media:config style.time.total "dim #2e8f5c"
```

```
▶︎ Rented Sunsets — Modem Chorus  ━┻┳━━━━━━━━┻┳━━━━━━━━┻┳━━━━━━━━┻┳━━━━━━━  1:32/4:07
```

The green is a long-persistence display phosphor, and the paused colour is
deliberately neither red nor yellow: on a monitor those two are standardised
alarm colours, and a paused song is not an alarm. Swap `heartbeat` for
`monitor` to trace it in braille, which has the rows to show the small P and
T bumps as well as the spike; `ekg` draws the beat up from the floor instead
of around a centre line.

## Night drive

Amber gauge glow for driving after dark — pausing flips the accent to a red
warning lamp.

![The Night drive recipe rendered live at one frame per second](recipes/night-drive.gif)

```
/media:config statusline.fields "track,progressbar,time"
/media:config style.progressbar.style knob
/media:config style.progressbar.playing "#ff9f0a"
/media:config style.progressbar.paused "#ff453a"
/media:config style.track.title "bold #ffb257"
/media:config style.track.artist "italic #c77f3d"
/media:config style.time.elapsed "bold #ff9f0a"
/media:config style.time.total "dim #c77f3d"
```

```
▶︎ Rented Sunsets — Modem Chorus  ━━━━━━●─────────────  1:32/4:07
```

## Synthwave

A hot-pink pulse under a chrome-cyan title — the neon-grid sunset palette.

![The Synthwave recipe rendered live at one frame per second](recipes/synthwave.gif)

```
/media:config statusline.fields "track,progressbar,time"
/media:config style.progressbar.style pulse
/media:config style.progressbar.playing "#ff2975"
/media:config style.progressbar.paused "#8c1eff"
/media:config style.track.title "bold underline #36f9f6"
/media:config style.track.artist "italic #ff2975"
/media:config style.time.elapsed "bold #ffd319"
/media:config style.time.total "dim #f222ff"
```

```
▶︎ Rented Sunsets — Modem Chorus  ▄▁▁▁▁▁▁█▁▁▄▁▁▁▁▁▁█▁▁  1:32/4:07
```

## Lo-fi

Dusty pastels and a short bar of marching notes — calm, low-contrast
study beats.

![The Lo-fi recipe rendered live at one frame per second](recipes/lo-fi.gif)

```
/media:config statusline.fields "track,progressbar,time"
/media:config style.progressbar.style notes
/media:config style.progressbar.length 12
/media:config style.progressbar.playing "#d6b2c2"
/media:config style.progressbar.paused "#b7a9c6"
/media:config style.track.title "bold #e4cba8"
/media:config style.track.artist "italic #a4c8e1"
/media:config style.time.elapsed "#d6b2c2"
/media:config style.time.total "dim #b7a9c6"
```

```
▶︎ Rented Sunsets — Modem Chorus  ·♫♪♫··♪♫♪··♫  1:32/4:07
```

## Neko

A cat padding down a dotted road, in warm paper tones — the terminal
creature, which walked a command line long before anything walked a
desktop.

![The Neko recipe rendered live at one frame per second](recipes/neko.gif)

```
/media:config statusline.fields "track,progressbar,time"
/media:config style.progressbar.style cat
/media:config style.progressbar.playing "#f4e4c1"
/media:config style.progressbar.paused "#8a7f6a"
/media:config style.track.title "bold #fbf3e2"
/media:config style.track.artist "italic #b3a488"
/media:config style.time.elapsed "bold #f4e4c1"
/media:config style.time.total "dim #6f6656"
```

```
▶︎ Rented Sunsets — Modem Chorus  ━━━━━━ᓚᘏᗢ┈┈┈┈┈┈┈┈┈┈┈  1:32/4:07
```

`snake`, `duck` and `bird` walk their own tracks, and `sprite` takes any
frames you like:

```
/media:config style.progressbar.style sprite
/media:config style.progressbar.sprite "◐ ◓ ◑ ◒"
/media:config style.progressbar.trail "═"
/media:config style.progressbar.track "┈"
```

This is the one family that needs no color at all — the creature stands
where the track has got to, so position alone carries the progress.

## Twilight

Soft indigo, periwinkle, and lavender over a smooth bar — the modern
dark-theme pastel look.

![The Twilight recipe rendered live at one frame per second](recipes/twilight.gif)

```
/media:config style.progressbar.style smooth
/media:config style.progressbar.playing "#79a0f5"
/media:config style.progressbar.paused "#dfae66"
/media:config style.track.title "bold #bfc9f4"
/media:config style.track.artist "italic #ba99f5"
/media:config style.app "#555e87"
/media:config style.time.elapsed "bold #7bcdfd"
/media:config style.time.total "dim #555e87"
```

```
▶︎ Rented Sunsets — Modem Chorus (Aux)  ███████▌░░░░░░░░░░░░  1:32/4:07
```

No truecolor (Apple Terminal, say)? Swap just the hex keys for named colors
— the same pattern works for any recipe on this page:

```
/media:config style.progressbar.playing bright-blue
/media:config style.progressbar.paused yellow
/media:config style.track.title "bold bright-white"
/media:config style.track.artist "italic bright-magenta"
/media:config style.time.elapsed "bold bright-cyan"
/media:config style.app reset
/media:config style.time.total reset
```
