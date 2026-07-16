# ステータスライン レシピ

[English](recipes.md) | [한국어](recipes.ko.md) | **日本語** | [简体中文](recipes.zh-CN.md)

now-playing セグメントにそのまま貼れる完成 look 集です。どれも
見覚えのあるものに根ざしています — 蛍光体ターミナル、テープデッキ、
チューナーダイヤル、ミキシングコンソール。色の出どころも実物そのもの:
蛍光体の輝線、顔料、文書に残る規格です。以下のコマンドはすべて実際の
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

タイトルと現在位置だけ — marquee も切って、動くのは時計だけです。

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

黒地に白と細い line バー — ポケットプレーヤーの OLED の look。named color
だけで組みます。

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

純 ASCII で色なし — 印字されたターミナルログのような姿。プレーンな
ターミナルや `NO_COLOR` 環境向けです。

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

## Plasma

ほぼ黒の地にオレンジのセル — ネオンガスパネルです。セルは点いているか
いないかのどちらかで、その中間はありません。

![Plasma レシピの実レンダリング（毎秒 1 フレーム）](recipes/plasma.gif)

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

このオレンジはネオン自身の色です — 可視域で最も強い 2 本の輝線が
585 nm と 640 nm にあります。バーを `rise`・`fade`・`corner` に替えると、
同じ塗りがセル単位ではなく 1/8・1/3・1/4 ずつ伸びます。このパネルの
ドットマトリクス版は `braille`（部分セルの双子は `stipple`）です。

## Phosphor

黒地に緑の単色と塗りつぶしブロックのバー — グリーン蛍光体の CRT
ターミナルです。

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

アンバー蛍光体のいとこにするには、`#33ff33`/`#22bb33`/`#22aa22` を
`#ffb000`/`#cc8400`/`#996300` に替えてください。

## Goban

粘板岩の黒とハマグリの白 — 碁石です。黒石は小さく見えるので 0.3 mm
大きく削り、二つが同じ大きさに見えるようにしてあります。

![Goban レシピの実レンダリング（毎秒 1 フレーム）](recipes/goban.gif)

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

ウール地に金糸の線 — 袖のシェブロンです。1777 年から意味してきたことは
ただ一つ、勤めた時間です。

![Service レシピの実レンダリング（毎秒 1 フレーム）](recipes/service.gif)

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

半分のタイルで終わる白い釉薬 — 駅の壁タイルです。白く焼いたのは、
地下で光を返してくれるからでした。

![Platform レシピの実レンダリング（毎秒 1 フレーム）](recipes/platform.gif)

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

`◧` は妥協ではありません — タイルの一列は実際に半分のタイルで終わり、
だからこそ境界のセルに描くものがあるのです。

## Telegraph

真鍮とニス塗りのオーク、そして境界で点が太くなってダッシュに変わる姿 —
電信のいちばん古い規則です。ダッシュとは点 3 つをつないだものですから。

![Telegraph レシピの実レンダリング（毎秒 1 フレーム）](recipes/telegraph.gif)

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

あたたかいテープデッキ: カセット窓のバー、♪ の階段レベル、クリームと
アンバーの文字。

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

40 セルのヘアラインスケールと赤い針 — シルバーフェイス機のバックライト
付きチューナーダイヤルです。文字はアイスブルーで。

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

## Vernier

焼き入れ鋼と真鍮のつまみ。ヘッドがヘアラインスケールを滑り、目盛と目盛の
*あいだ*に止まります — 1631 年からバーニヤがしてきたのは、まさにそれです。

![Vernier レシピの実レンダリング（毎秒 1 フレーム）](recipes/vernier.gif)

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

40 ではなく 36 なのには理由があります。`glide` のヘッドは半セル位置で
しか `╾` に割れませんが、この例の再生位置だと 40 セルのバーはちょうど
境界に乗ってしまい、`╾` を一度も見せません。

## VFD

暗い地にシアングリーンのセグメント — 90 年代ハイファイの蛍光表示管
フロントパネルです。アプリ名がソースラベルの役をします。

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

ミキシングデスク風の 2 段: 上にメーターとタイムコード、下にトランスポートと
モニター — LED グリーンとレコードレッド。

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
🔉 ▁▄▄▆▄▅▄▇ 35%  ▅▅▅▆▄▄▆▆▆▆▂▂▃▃▅▆▄▅▄▄  1:32/4:07
▶︎ Rented Sunsets — Modem Chorus (Aux)  🎚 Bookshelf Speakers
```

音量ミニメーターはプログレスバーの `eq` 文字をそのまま借りるので、
一緒に揺れます。

## Slider wall

クリームと黒、そして赤い上端 — VU メーターです。針をわざと遅くして、
瞬間音を追いかけるかわりに音の大きさを見せてくれます。

![Slider wall レシピの実レンダリング（毎秒 1 フレーム）](recipes/slider-wall.gif)

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

`bars` は基音に非整数次の倍音と下位倍音を重ねて形を作ります — だから
和音ではなく実際の音源のように動きます。ブロック高さ版が欲しければ `eq`
を使ってください。それが [Console](#console) です。

## Third-octave

伸びずにその場で踊る赤い LED の柱 — 1/3 オクターブアナライザーです。
バンドの中心が固定なので、バーを広げると同じ区間を広く見るのではなく、
スペクトルをより多く見ることになります。

![Third-octave レシピの実レンダリング（毎秒 1 フレーム）](recipes/third-octave.gif)

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

この赤は、最初の可視光 LED 自身の色です — ガリウムヒ素リン、
655 nm、1962 年。`spectrum` を `cava` に替えると、同じ解析を braille の
点で、横方向 2 倍の密度で描きます。

## Seiche

器の中で揺れる湖ぜんたい — 湖盆の幅がどうであれ、その中にぴたりと
収まる定常波です。このバーが長さによらず同じ 2.5 個の波を見せるのも
そのためです。

![Seiche レシピの実レンダリング（毎秒 1 フレーム）](recipes/seiche.gif)

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

藍から緑へという向きは、湖水の色スケールが並んでいる向きそのものです —
seiche に名をつけた人が、そのスケールも作りました。`wave` を `swell` に
替えると braille の双子になります。

## Ripple tank

上にランプ、下に水を張った盆、真ん中を叩く針 — 波が自分の影を中心から
外へ投げます。光が波であることを示すために作られた装置です。

![Ripple tank レシピの実レンダリング（毎秒 1 フレーム）](recipes/ripple-tank.gif)

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

同じ形の braille の双子は `ripple` です。

## Lead II

毎秒 25 ミリメートルで流れるトレース — 世界じゅうが合意した記録紙の
速度です。バーが長くなると拍が広がるのではなく増えるのは、これが理由です。

![Lead II レシピの実レンダリング（毎秒 1 フレーム）](recipes/lead-ii.gif)

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

緑は長残光の表示管蛍光体の色で、一時停止の色が赤でも黄でもないのは
意図的です。その二つは、モニターでは規格で定められた警報色ですが、
一時停止した曲は警報ではありません。`heartbeat` を `monitor` に替えると
braille で描き、点の段に余裕があるのでスパイクだけでなく小さな P 波と
T 波のふくらみまで見せます。`ekg` は中心線のまわりではなく、床から上へ
拍を描きます。

## Night drive

夜の運転のためのアンバーの計器光 — 一時停止するとアクセントが赤い警告灯に
変わります。

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

クロムシアンのタイトルの下にホットピンクの pulse — ネオングリッドの
サンセットパレットです。

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
▶︎ Rented Sunsets — Modem Chorus  ▄▁▁▁▁▁▁█▁▁▄▁▁▁▁▁▁█▁▁  1:32/4:07
```

## Lo-fi

くすんだパステルと音符が行進する短いバー — 穏やかで低コントラストの
スタディビート。

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
▶︎ Rented Sunsets — Modem Chorus  ·♫♪♫··♪♫♪··♫  1:32/4:07
```

## Neko

あたたかい紙の色で、点線の道を歩く猫 — ターミナルの生きものです。
何かがデスクトップを歩くよりずっと前から、コマンドラインを歩いて
いました。

![Neko レシピの実レンダリング（毎秒 1 フレーム）](recipes/neko.gif)

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

`snake`・`duck`・`bird` はそれぞれのトラックを歩き、`sprite` は好きな
フレームをそのまま受け取ります:

```
/media:config style.progressbar.style sprite
/media:config style.progressbar.sprite "◐ ◓ ◑ ◒"
/media:config style.progressbar.trail "═"
/media:config style.progressbar.track "┈"
```

色がまったく要らない唯一の系です — 生きものが曲の現在位置に立つので、
位置だけで進み具合が読めます。

## Twilight

やわらかいインディゴ、ペリウィンクル、ラベンダーを smooth バーの上に —
いまどきのダークテーマのパステル look です。

![Twilight レシピの実レンダリング（毎秒 1 フレーム）](recipes/twilight.gif)

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

truecolor が使えない場合（Apple Terminal など）は、hex のキーだけを
named color に替えれば大丈夫 — このページのどのレシピでも同じ手が
使えます:

```
/media:config style.progressbar.playing bright-blue
/media:config style.progressbar.paused yellow
/media:config style.track.title "bold bright-white"
/media:config style.track.artist "italic bright-magenta"
/media:config style.time.elapsed "bold bright-cyan"
/media:config style.app reset
/media:config style.time.total reset
```
