# ステータスライン レシピ

[English](recipes.md) | [한국어](recipes.ko.md) | **日本語** | [简体中文](recipes.zh-CN.md)

now-playing セグメントにそのまま貼れる完成 look 集です。どれも
見覚えのあるものに根ざしています — 蛍光体ターミナル、テープデッキ、
チューナーダイヤル、ミキシングコンソール。以下のコマンドはすべて実際の
`media.sh config` の検証を通り、GIF はすべてレンダラーの実出力（毎秒
1 フレーム）です。（すべて架空のトラック — *Modem Chorus* の *Rented
Sunsets*、架空のアプリ *Aux* で再生中。）

適用するには: ブロックの行を 1 行ずつ Claude に貼るか、ブロックごと渡して
「このとおり適用して」と言うだけ。変更は次の statusline ティックで反映
されます — 再起動不要。

各レシピは**ストック（初期）状態**を起点にします。別のレシピや自前の
カスタマイズから乗り換えるときは、まずリセットを — 抜けるときも同じ
コマンドです:

```
/media:config statusline reset
```

（キーごとの詳細は[スタイルギャラリー](styles.ja.md)、リセット系は
[デフォルトに戻す](styles.ja.md#デフォルトに戻す)へ。）

hex 色は 24-bit truecolor で描かれます — ほとんどのターミナルは対応、
Apple Terminal は非対応です。[Twilight](#twilight) の末尾に、どの
レシピにも使える named-color への置き換えパターンがあります。

## Zen

タイトルと現在位置だけ — marquee も切って、動くのは時計だけ。

![Zen レシピの実レンダリング（毎秒 1 フレーム）](recipes/zen.gif)

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

黒地に白、細い line バー — ポケットプレーヤーの OLED 画面の look。named
color のみ。

![Mono レシピの実レンダリング（毎秒 1 フレーム）](recipes/mono.gif)

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

純 ASCII・無色 — 印字したターミナルログのような姿。プレーンなターミナルや
`NO_COLOR` 環境に。

![Hardcopy レシピの実レンダリング（毎秒 1 フレーム）](recipes/hardcopy.gif)

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

黒地に緑一色、ソリッドなブロックバー — 緑蛍光体の CRT ターミナル。

![Phosphor レシピの実レンダリング（毎秒 1 フレーム）](recipes/phosphor.gif)

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

アンバー蛍光体版は `#33ff33`/`#22bb33`/`#22aa22` を
`#ffb000`/`#cc8400`/`#996300` に差し替えるだけ。

## Cassette

温かいテープデッキ: カセット窓のバー、♪ の階段レベル、クリーム &
アンバーのレタリング。

![Cassette レシピの実レンダリング（毎秒 1 フレーム）](recipes/cassette.gif)

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

40 マスのヘアライン目盛りに赤い針 —
シルバーフェイスのレシーバーのバックライト付きチューナーダイヤル、アイスブルーの文字。

![Dial レシピの実レンダリング（毎秒 1 フレーム）](recipes/dial.gif)

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

暗い地に青緑のセグメント — 90 年代ハイファイの前面 VFD
パネル。アプリ名がソースラベルの役を務めます。

![VFD レシピの実レンダリング（毎秒 1 フレーム）](recipes/vfd.gif)

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

ミキシングデスク式の 2 段:
上にメーターとタイムコード、下にトランスポートとモニター — LED
グリーン、録音レッド。

![Console レシピの実レンダリング（毎秒 1 フレーム）](recipes/console.gif)

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
🔉 ▁▄▄▁▁▁▁▁ 35%  ▅▅▅▆▄▄▆▁▁▁▁▁▁▁▁▁▁▁▁▁  1:32/4:07
▶︎ Rented Sunsets — Modem Chorus (Aux)  🎚 Bookshelf Speakers
```

音量のミニメーターはプログレスバーの `eq`
文字をそのまま借りて、いっしょに跳ねます。

## Night drive

夜間走行のアンバー計器グロー —
一時停止でアクセントが赤い警告灯に変わります。

![Night drive レシピの実レンダリング（毎秒 1 フレーム）](recipes/night-drive.gif)

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

クロム・シアンのタイトルの下にホットピンクのパルス —
ネオングリッドのサンセットパレット。

![Synthwave レシピの実レンダリング（毎秒 1 フレーム）](recipes/synthwave.gif)

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
▶︎ Rented Sunsets — Modem Chorus  ▃▂▂▂▂▂▂▁▁▁▁▁▁▁▁▁▁▁▁▁  1:32/4:07
```

## Lo-fi

くすんだパステルと短い音符バー — 落ち着いた低コントラストの study beats。

![Lo-fi レシピの実レンダリング（毎秒 1 フレーム）](recipes/lo-fi.gif)

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

smooth バーにインディゴ・ペリウィンクル・ラベンダーのパステル —
モダンなダークテーマのパステル look、すべて正確な hex で。

![Twilight レシピの実レンダリング（毎秒 1 フレーム）](recipes/twilight.gif)

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

truecolor のないターミナル（例: Apple Terminal）では、hex のキーだけ named
color に差し替えてください —
このページのどのレシピにも同じパターンが使えます:

```
/media:config style.progressbar.playing bright-blue
/media:config style.progressbar.paused yellow
/media:config style.track.title "bold bright-white"
/media:config style.track.artist "italic bright-magenta"
/media:config style.time.elapsed "bold bright-cyan"
/media:config style.app reset
/media:config style.time.total reset
```
