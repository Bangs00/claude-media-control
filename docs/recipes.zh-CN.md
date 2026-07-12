# 状态栏现成搭配

[English](recipes.md) | [한국어](recipes.ko.md) | [日本語](recipes.ja.md) | **简体中文**

现成的 now-playing 组件整套外观，直接粘贴即用。每一款都源自你认得出的
原型——荧光体终端、磁带卡座、调谐刻度盘、调音台。下面每条命令都通过了真实的
`media.sh config` 校验，每张 GIF 都是渲染器的真实输出（每秒 1 帧）。
（全程使用虚构曲目——*Modem Chorus* 的 *Rented Sunsets*，在虚构应用
*Aux* 中播放。）

应用方法：把代码块里的命令一行行发给 Claude，或整块交给它说"照这个
设置"。改动会在下一次状态栏刷新时生效——无需重启。

每款搭配都以**出厂状态**为起点。若刚用过别的搭配或自己改过样式，先
重置——退出任何搭配也是同一条命令：

```
/media:config statusline reset
```

（逐键说明见[样式图鉴](styles.zh-CN.md)；重置系列见
[恢复默认](styles.zh-CN.md#恢复默认)。）

十六进制色以 24-bit truecolor 渲染——多数终端支持，Apple Terminal
不支持。[Twilight](#twilight) 结尾给出了适用于任何搭配的 named-color
替换方案。

## Zen

只留标题和播放位置——连 marquee 也关掉，会动的只有时间。

![Zen 搭配的真实渲染（每秒 1 帧）](recipes/zen.gif)

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

黑底白字、细 line 条——口袋播放器 OLED 屏的样子，只用 named color。

![Mono 搭配的真实渲染（每秒 1 帧）](recipes/mono.gif)

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

纯 ASCII、零颜色——像打印出来的终端日志，适合朴素终端和 `NO_COLOR` 环境。

![Hardcopy 搭配的真实渲染（每秒 1 帧）](recipes/hardcopy.gif)

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

黑底纯绿加实心块条——绿荧光体 CRT 终端。

![Phosphor 搭配的真实渲染（每秒 1 帧）](recipes/phosphor.gif)

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

想要琥珀荧光体版本，把 `#33ff33`/`#22bb33`/`#22aa22` 换成
`#ffb000`/`#cc8400`/`#996300` 即可。

## Cassette

温暖的磁带卡座：卡带窗进度条、♪ 阶梯音量、奶油-琥珀色字。

![Cassette 搭配的真实渲染（每秒 1 帧）](recipes/cassette.gif)

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

40 格细线刻度上一根红针——银面收音机的背光调谐刻度盘，冰蓝色字。

![Dial 搭配的真实渲染（每秒 1 帧）](recipes/dial.gif)

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

深底青绿荧光段——90 年代高保真音响前面板的 VFD 屏，应用名充当输入源标签。

![VFD 搭配的真实渲染（每秒 1 帧）](recipes/vfd.gif)

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

调音台式上下两行：上排电平表和时间码，下排走带和监听——LED 绿、录音红。

![Console 搭配的真实渲染（每秒 1 帧）](recipes/console.gif)

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
🔉 ▅▆▂▁▁▁▁▁ 35%  ▅▆▂▇▃█▅▁▁▁▁▁▁▁▁▁▁▁▁▁  1:32/4:07
▶︎ Rented Sunsets — Modem Chorus (Aux)  🎚 Bookshelf Speakers
```

音量迷你表直接借用进度条的 `eq` 字符，一起跳动。

## Night drive

夜路仪表盘的琥珀光——一暂停，强调色就切成红色警示灯。

![Night drive 搭配的真实渲染（每秒 1 帧）](recipes/night-drive.gif)

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

铬青色标题下的荧光粉脉冲——霓虹网格落日配色。

![Synthwave 搭配的真实渲染（每秒 1 帧）](recipes/synthwave.gif)

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
▶︎ Rented Sunsets — Modem Chorus  ▁▄▂▂█▁▄▁▁▁▁▁▁▁▁▁▁▁▁▁  1:32/4:07
```

## Lo-fi

灰调粉彩配一小段行进音符——低对比、安安静静的学习节拍。

![Lo-fi 搭配的真实渲染（每秒 1 帧）](recipes/lo-fi.gif)

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
▶︎ Rented Sunsets — Modem Chorus  ♪♫♪♫········  1:32/4:07
```

## Twilight

smooth 条上的靛蓝·长春花·薰衣草粉彩——现代深色主题的粉彩外观，全部精确
hex。

![Twilight 搭配的真实渲染（每秒 1 帧）](recipes/twilight.gif)

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

终端不支持 truecolor（如 Apple Terminal）？只把 hex 键换成 named
color——本页任何搭配都适用同一套换法：

```
/media:config style.progressbar.playing bright-blue
/media:config style.progressbar.paused yellow
/media:config style.track.title "bold bright-white"
/media:config style.track.artist "italic bright-magenta"
/media:config style.time.elapsed "bold bright-cyan"
/media:config style.app reset
/media:config style.time.total reset
```
