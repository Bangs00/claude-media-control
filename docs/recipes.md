# Statusline recipes

**English** | [한국어](recipes.ko.md) | [日本語](recipes.ja.md) | [简体中文](recipes.zh-CN.md)

Ready-to-paste looks for the now-playing segment, each grounded in
something you would recognize — a phosphor terminal, a tape deck, a tuner
dial, a mixing console. Every command below went through the real
`media.sh config` validation, and every GIF is the renderer's own output
at one frame per second (all with a fictional track — *Rented Sunsets* by
*Modem Chorus*, playing in a fictional app called *Aux*).

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
▶︎ Rented Sunsets — Modem Chorus  ▃▂▂▂▂▂▂▇▃▂▂▂▂▂▂▇▃▂▂▂  1:32/4:07
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
▶︎ Rented Sunsets — Modem Chorus  ·♫♪♫········  1:32/4:07
```

## Twilight

Soft indigo, periwinkle, and lavender over a smooth bar — the modern
dark-theme pastel look, in exact hex.

![The Twilight recipe rendered live at one frame per second](recipes/twilight.gif)

```
/media:config style.progressbar.style smooth
/media:config style.progressbar.playing "#7aa2f7"
/media:config style.progressbar.paused "#e0af68"
/media:config style.track.title "bold #c0caf5"
/media:config style.track.artist "italic #bb9af7"
/media:config style.app "#565f89"
/media:config style.time.elapsed "bold #7dcfff"
/media:config style.time.total "dim #565f89"
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
