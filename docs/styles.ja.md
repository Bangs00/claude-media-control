# ステータスライン スタイルギャラリー

[English](styles.md) | [한국어](styles.ko.md) | **日本語** | [简体中文](styles.zh-CN.md)

再生中セグメントの目に見える部分は、すべて 1 つずつ設定キーになっています。
このページでは**用意されているスタイルの全部を、実際の見た目つきで**
紹介します。変え方は 2 通り:

```
/media:statusline                              # 対話形式 — または言葉でそのまま:
                                               #   「バーを dots に」「アーティストを隠して」
/media:config style.progressbar.style wave     # キーを直接設定
```

変更は次のステータスライン更新（1 秒以内)ですぐ反映されます。再起動は
一切不要です。`media.sh config style` を実行すると、全キーの現在値と
デフォルトが一覧できます。

## セグメントの解剖図

```
▶︎ Karma Police — Radiohead (Spotify)  🔉 ▄ 45%  ━━━━━━━━━━━━────────  2:13/4:24  🎧 AirPods Pro
```

| 見えるもの | キー | デフォルト |
| --- | --- | --- |
| `▶︎` / `⏸` 状態アイコン | 色は `style.progressbar.playing` / `.paused` に従う | `green` / `yellow` |
| `Karma Police` | `style.track.title` | `bold` |
| `— Radiohead` | `style.track.artist` | `italic` |
| `(Spotify)` | `style.app` | `dim` |
| `🔉` 音量アイコン | `style.volume.icon` | `auto` |
| `▄` 音量バー | `style.volume.style`（形） · `style.volume.bar`（表示） | `block` · `on` |
| `45%` | `style.volume.percent` | `dim` |
| `━━━━━━━━━━━━────────` | `style.progressbar.style`（文字） · `style.progressbar.length`（マス数） | `line` · `20` |
| `2:13` 経過時間 | `style.time.elapsed` | `bold` |
| `/4:24` 合計時間 | `style.time.total` | `dim` |
| `🎧` 出力アイコン | `style.output.icon` | `auto` |
| `AirPods Pro` | `style.output` | `dim` |

（どの項目をどの行に置くかは*配置*の仕事です —
[statusline.ja.md](statusline.ja.md) を参照。）

セグメント全体を **1 つのアクセントカラー**が貫きます: ▶︎/⏸ アイコン、
プログレスバーの塗り、音量バーは、再生中は `style.progressbar.playing`、
一時停止中は `.paused` の色で描かれます。

## プログレスバー

文字は `style.progressbar.style`、バーのマス数は
`style.progressbar.length`（デフォルト 20）で決まります。`/media:now` の
返信に出るバーも同じ文字・同じ長さで描かれるので、2 つの表示は常に
一致します。文字と長さの選択は色をオフにしていても有効です。

![バーのプリセットと音量の形が毎秒 1 フレームで動く様子](styles.gif)

### 静的なプリセット

60% 時点の見た目です（`smooth` と `rise` は、部分ブロックが見える 58%）:

| 値 | 見た目 | |
| --- | --- | --- |
| `line` | `━━━━━━━━━━━━────────` | デフォルト |
| `blocks` | `████████████░░░░░░░░` | クラシック（0.12 以前のデフォルト） |
| `smooth` | `███████████▋░░░░░░░░` | 境界のマスが部分ブロック — 下記参照 |
| `rise` | `███████████▅░░░░░░░░` | 境界のマスが下から満ちる — 下記参照 |
| `knob` | `━━━━━━━━━━━●────────` | スライダーのつまみが先端に付く |
| `braille` | `⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣀⣀⣀⣀⣀⣀⣀⣀` | |
| `chevron` | `▸▸▸▸▸▸▸▸▸▸▸▸▹▹▹▹▹▹▹▹` | |
| `tape` | `▰▰▰▰▰▰▰▰▰▰▰▰▱▱▱▱▱▱▱▱` | |
| `cassette` | `▮▮▮▮▮▮▮▮▮▮▮▮▯▯▯▯▯▯▯▯` | |
| `retro` | `============--------` | 純粋な ASCII |
| `dots` | `●●●●●●●●●●●●○○○○○○○○` | |

`smooth` は ⅛ マス刻みで満ちていくので、短い曲でも秒と秒のあいだの進みが
目に見えます:

```
 3%  ▋░░░░░░░░░░░░░░░░░░░
47%  █████████▍░░░░░░░░░░
98%  ███████████████████▋
```

`rise` は同じ ⅛ 刻みを下から上へ積み上げます — 各マスが ▁▂▃▄▅▆▇ を
経て満ちます:

```
 3%  ▅░░░░░░░░░░░░░░░░░░░
47%  █████████▃░░░░░░░░░░
98%  ███████████████████▅
```

### 動くプリセット

この 4 つは再生中、波形が毎秒 1 マスずつ空き側へ流れ、一時停止すると
止まります:

| 値 | t | t+1秒 | t+2秒 | |
| --- | --- | --- | --- | --- |
| `wave` | `▂▄▆▄▂▄▆▄▂▄▆▄▁▁▁▁▁▁▁▁` | `▄▂▄▆▄▂▄▆▄▂▄▆▁▁▁▁▁▁▁▁` | `▆▄▂▄▆▄▂▄▆▄▂▄▁▁▁▁▁▁▁▁` | うねる波 |
| `pulse` | `▂▂█▁▄▂▂█▁▄▂▂▁▁▁▁▁▁▁▁` | `▄▂▂█▁▄▂▂█▁▄▂▁▁▁▁▁▁▁▁` | `▁▄▂▂█▁▄▂▂█▁▄▁▁▁▁▁▁▁▁` | 心電図の拍動 |
| `eq` | `▂▇▃█▅▆▂▇▃█▅▆▁▁▁▁▁▁▁▁` | `▆▂▇▃█▅▆▂▇▃█▅▁▁▁▁▁▁▁▁` | `▅▆▂▇▃█▅▆▂▇▃█▁▁▁▁▁▁▁▁` | イコライザー |
| `notes` | `♪♫♪♫♪♫♪♫♪♫♪♫········` | `♫♪♫♪♫♪♫♪♫♪♫♪········` | `♪♫♪♫♪♫♪♫♪♫♪♫········` | 行進する音符 |

### 好きな文字で

**ちょうど 2 文字**を渡すと「塗り + 空き」になります（空き側に半角
スペースも使えます。スペース 2 つ、タブ、改行は拒否されます）:

```
/media:config style.progressbar.style "#-"     →  ############--------
/media:config style.progressbar.style "~ "     →  ~~~~~~~~~~~~
```

### バーの長さ

`style.progressbar.length` がバーの占めるマス数を決めます — 1 から 60
までの整数、デフォルトは `20`:

```
/media:config style.progressbar.length 10   →  ━━━━━━────
/media:config style.progressbar.length 40   →  ━━━━━━━━━━━━━━━━━━━━━━━━────────────────
```

1 つの長さがステータスラインのセグメントと `/media:now` のバーを一緒に
動かします。リンクがオンなら全マスがそのまま ⌘+クリックの対象なので、
バーが長いほどシークは細かくなります。（音量ミニバーはあえて小さくして
あるため 5 マスのままです。）デフォルトは 0.20.0 で 10 マスから 20 マスに
広がりました — `10` に設定すれば以前のコンパクトなバーに戻ります。

### バーの色

`style.progressbar.playing`（デフォルト `green`）と `.paused`（デフォルト
`yellow`）が塗りの色を決めます — セグメントはアクセントカラーを 1 つ
共有するので、▶︎/⏸ アイコンと音量バーも一緒に変わります。空きマスは常に
薄く（dim）表示されます。

```
/media:config style.progressbar.playing bright-cyan
/media:config style.progressbar.paused magenta
```

## 音量

`volume` 項目は**アイコン + バー + パーセント**（`🔉 ▄ 45%`）で描かれ、
ミュート中は `🔇` 1 つに畳まれます。（native helper が必要です —
`/media:doctor` を参照。）

### バーの形 — `style.volume.style`

| 値 | 10% | 30% | 45% | 60% | 80% | 100% | |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `block` | `▁` | `▃` | `▄` | `▅` | `▇` | `█` | 1 マス、高さ = 音量（デフォルト） |
| `stairs` | `▂` | `▂▄` | `▂▄` | `▂▄▆` | `▂▄▆█` | `▂▄▆█` | 4 段の階段 |
| `progress` | `━────` | `━━───` | `━━───` | `━━━──` | `━━━━─` | `━━━━━` | 5 マスのミニバー |

`progress` はプログレスバーと同じ文字で描かれます — アニメーションも
そのまま。`blocks` なら `██░░░`、`dots` なら `●●○○○`。音量バーの色は常に
再生 / 一時停止のアクセントに従い、`style.volume.bar off` はバーだけを
隠します（`🔉 45%`）。

### 音量アイコン — `style.volume.icon`

| 値 | 見た目 |
| --- | --- |
| `auto`（デフォルト） | `🔈` 小 · `🔉` 中 · `🔊` 大 · `🔇` ゼロのとき |
| `none` | 非表示 — `▄ 45%` |
| 任意のグリフ、例: `♪` | `♪ ▄ 45%` |

ミュート中はアイコン設定にかかわらず、常に `🔇` が出ます。

### パーセント — `style.volume.percent`

テキストスタイル（デフォルト `dim`）を受け付け、`off` で消えます: `🔉 ▄`。

## 出力デバイス

`output` 項目はアイコン + デバイス名です: `🎧 AirPods Pro`。

| キー | 値 |
| --- | --- |
| `style.output.icon` | `auto`（デフォルト）= デバイス種別ごと: `🎧` Bluetooth・ヘッドフォン端子 · `📺` HDMI/DisplayPort · `📶` AirPlay · `🔊` スピーカー — または `none`、または任意のグリフ |
| `style.output` | デバイス名のテキストスタイル（デフォルト `dim`）、`off` でアイコンのみ |

## テキストスタイル

テキストのパーツ — 曲名、アーティスト、アプリ、経過 / 合計時間、音量
パーセント、出力デバイス名 — はすべて**スタイル指定**を受け付けます:

- `bold`、`dim`、`italic`、`underline` をいくつでも
- 色は最大 1 つ: `black` `red` `green` `yellow` `blue` `magenta` `cyan`
  `white`、または `bright-<色>`（実際の色味はターミナルのパレット次第 —
  標準 16 色の SGR のみ使用）
- または `none` — スタイルなし
- または `off` — **そのパーツを非表示**

```
/media:config style.track.title "bold bright-cyan"
/media:config style.track.artist off
```

非表示は周りも一緒に片づけます: 曲名を隠せば `—` の区切りも消え、経過時間を
隠せば合計時間の前の `/` も消え、パーツが全部隠れた項目は項目ごと消えます。
（項目を丸ごと外すのは配置の仕事です — `/media:statusline`。）

スタイル指定が描かれるのは `statusline.color` がオンのときだけです
（`NO_COLOR` が常に優先）。文字を変えるもの — バーの文字、音量バーの形、
アイコン — と `off` は、色のオン / オフに関係なく効きます。

## レシピ

そのまま貼り付けられる 4 つのルックです。色はこのページでは見えないので、
実際のステータスラインで確かめてください。

**ミニマル** — 曲名と経過時間だけ:

```
/media:config statusline.fields "track,time"
/media:config style.track.artist off
/media:config style.time.total off
```
```
▶︎ Karma Police  2:13
```

**ナイトドライブ** — ネオンの dots + シアンの曲名:

```
/media:config style.progressbar.style dots
/media:config style.progressbar.playing bright-magenta
/media:config style.track.title "bold bright-cyan"
```
```
▶︎ Karma Police — Radiohead (Spotify)  ●●●●●●●●●●●●○○○○○○○○  2:13/4:24
```

**テープデッキ** — テープ型バー、階段の音量、音符アイコン:

```
/media:config statusline.fields "track,app,volume,progressbar,time"
/media:config style.progressbar.style tape
/media:config style.volume.style stairs
/media:config style.volume.icon ♪
```
```
▶︎ Karma Police — Radiohead (Spotify)  ♪ ▂▄ 45%  ▰▰▰▰▰▰▰▰▰▰▰▰▱▱▱▱▱▱▱▱  2:13/4:24
```

**素のターミナル** — ASCII バー、色なし:

```
/media:config style.progressbar.style retro
/media:config statusline.color off
```
```
▶︎ Karma Police — Radiohead (Spotify)  ============--------  2:13/4:24
```

## デフォルトに戻す

```
/media:config style.track.title reset     # キー 1 つだけ
/media:config style reset                 # すべての style.* キー
/media:config statusline reset            # スタイルに加えて配置・行・色・
                                          # marquee まで丸ごと初期状態へ
```
