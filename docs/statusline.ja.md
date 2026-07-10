# ステータスラインに再生中の曲を出す

[English](statusline.md) | [한국어](statusline.ko.md) | **日本語** | [简体中文](statusline.zh-CN.md)

Claude Code のステータスラインに、いま再生している曲を 1 行追加できます:

```
[既存のステータスラインはそのまま]
▶︎ Karma Police — Radiohead  ██████░░░░  2:13/4:24
```

この行を作るのは `media.sh statusline` です。小さな TTL キャッシュ
（デフォルト 1 秒）から 50ms を大きく下回る速さで応答するので、ステータス
ラインが遅くなることはありません。実際の再生情報の読み取りは TTL の区間ごと
に最大 1 回だけ。そのためステータスラインが再描画されるたび、経過時間と
プログレスバーはおよそ 1 秒刻みで進んでいきます。

## 設計上の保証（安心して追加できる理由）

1. 既存のステータスラインコマンドは**置き換えません**。ラッパーがまず
   それを、元のまま実行します。
2. その出力は**1 バイトも変えずに**素通しします。
3. 再生情報は必ず**独立した 1 行として追加されるだけ**です。
4. `display.statusline` がオフのとき（デフォルト）、セグメントのコマンドは
   何も出力しません。空行すら出しません。Claude Code は存在しない行を
   詰めてくれるので、ステータスラインの見た目は以前とまったく同じです。

プラグインが `settings.json` を勝手に書き換えることはありません。以下の
手順はすべて手作業の、いつでも元に戻せる変更です。

## ステップ 1 — セグメントを有効にする

Claude Code の中で:

```
/media:config display.statusline on
```

（有効化の前に、再生情報を実際に読み取れるかを検証します。拒否された場合は
`/media:doctor` を実行してみてください。）

### 項目を配置する

`/media:statusline` を実行すると、2 つのプリセット（Standard / Stacked）を
プレビューで見比べながら選べます。`Custom…` を選べば、数字パターンひとつを
チャット入力欄にそのまま打ち込むだけで、どの項目をどの行にどの順序で置くかを
自由に決められます: `1` track、`2` app、`3` 音量、`4` 進行バー、`5` 時間、
`6` 出力デバイス — `/` で新しい行が始まり、数字の並びがそのまま表示順になり、
書かなかった数字の項目は表示されません。`123/456` なら 1 行目に track・
アプリ・音量、2 行目にバー・時間・出力デバイスが並びます。簡易版のプリセット
ピッカーは `/media:config` の中からも開けます:

- **項目**（自由な組み合わせで、**好きな順序に**）: `track`（▶︎ 曲名 —
  アーティスト）、`app`（再生中のアプリ、例: `(Spotify)`）、`volume`
  （システム音量をアイコン + 音量に応じた高さのバー + パーセントで、例:
  `🔉 ▄ 45%`。ミュート中は `🔇`）、`progressbar`（`██████░░░░`）、
  `time`（`2:13/4:24`）、`output`（現在のオーディオ出力デバイス — アイコンは
  デバイスの種類に合わせて変わります: Bluetooth・ヘッドホンジャックは `🎧`、
  HDMI/DisplayPort は `📺`、AirPlay は `📶`、スピーカーは `🔊`）。デフォルト
  の構成は `track app progressbar time` です。
- **順序**: 項目は保存した順序どおりに描画されます。「時間を先頭に」
  「出力デバイスを前に」と頼んでもいいし、直接指定もできます:
  `/media:config statusline.fields "time,progressbar,track,app"`。
- **行の割り当て**: 項目リストに `/` を入れると、そこで行が変わり、リスト
  全体が行単位の明示レイアウトに切り替わります — 各行にはそこに置いた項目
  だけがその順序で表示され、表示するものがない行は行ごと消えます（例:
  ネイティブヘルパーがないときの `output`・`volume`）。`/` がなければ従来の
  グループレイアウトのままです: 1 行にまとめるか、グループごとに行を分けるか
  （`statusline.multiline on`）— `app` は track のグループに付き、
  `progressbar` と `time` は順序上隣り合っているときに 1 つのグループに
  なり、`output` と `volume` は隣り合う track グループに合流し、両者が
  隣り合えば 2 つで 1 つのグループになります。

Standard — 全項目を 1 行で（パターン `123456`）:

```
▶︎ Karma Police — Radiohead (Spotify)  🔉 ▄ 45%  ██████░░░░  2:13/4:24  🎧 AirPods Pro
```

Stacked — 明示的な 2 行レイアウト（パターン `123/456`、つまり
`statusline.fields "track,app,volume,/,progressbar,time,output"`）:

```
▶︎ Karma Police — Radiohead (Spotify)  🔉 ▄ 45%
██████░░░░  2:13/4:24  🎧 AirPods Pro
```

出力デバイスを track の行に、音量は外して（パターン `126/45`）:

```
▶︎ Karma Police — Radiohead (Spotify)  🎧 AirPods Pro
██████░░░░  2:13/4:24
```

時間を先頭に、1 行で（パターン `5412`、つまり
`statusline.fields "time,progressbar,track,app"`）:

```
2:13/4:24  ██████░░░░  ▶︎ Karma Police — Radiohead (Spotify)
```

`output` と `volume` の項目にはネイティブヘルパーが必要です（セグメントが
元々行う読み取りに相乗りするため、追加コストはありません）。デバイスの
切り替えは `/media:output`、音量の変更は `/media:volume` で行え、セグメント
には次の更新で反映されます。

### 長いタイトル: マーキースクロール

30 セル（ターミナルの桁数）を超えるタイトルは、固定幅 30 セルの窓の中を
1 秒に 1 文字ずつ流れていきます（下記の 1 秒リフレッシュと連動して、再描画の
たびに 1 文字進みます）:

```
▶︎ ing Willow (10 Minute Version)  — Taylor Swift (Music)
```

漢字・かな・ハングルは 2 セルとして数えるので、CJK のタイトルでも窓の幅は
一定に保たれます。どんなに長くてもタイトル全体を表示したい場合はオフに
できます:

```
/media:config statusline.marquee off
```

### 色とパーツごとのスタイル

セグメントはデフォルトでスタイル付きです。Claude Code のステータスラインは
ANSI コードをレンダリングでき、下のラッパーはそれを手を加えずに通します:

- アイコンとプログレスバーの塗りつぶし部分は、再生状態に合わせて色が
  変わります（再生中は green、一時停止中は yellow）
- **太字**の曲名と経過時間（動き続ける部分なのでくっきり見えます）、
  *斜体*のアーティスト、薄い表示の合計時間・空きセル・アプリ名・出力デバイス

使うのは標準の 16 色 SGR コードだけなので、実際の色味はターミナル自身の
パレットに従います。プレーンテキストがよければ
`/media:config statusline.color off` を実行してください。`NO_COLOR`
環境変数も有効です。

さらに、**どのパーツも個別にスタイリングできます**。`/media:style` を実行
して希望を言葉で伝えるか（「曲名を太字のシアンに」「バーのスタイルを wave
に」「音量アイコンを ♪ に」）、キーを直接設定してください。各キーは
`bold dim italic underline` の組み合わせに色を 1 つ（`black red green
yellow blue magenta cyan white` または `bright-<色>`）、あるいは
`none`（スタイルなし）を受け付けます:

| キー | 対象 | デフォルト |
| --- | --- | --- |
| `style.track.title` / `style.track.artist` | 曲名 / アーティスト | `bold` / `italic` |
| `style.app` | アプリ名 `(Spotify)` | `dim` |
| `style.time.elapsed` / `style.time.total` | `2:13` / `/4:24` | `bold` / `dim` |
| `style.volume.icon` / `style.volume.bar` / `style.volume.percent` | 音量アイコン / バー / パーセント | `auto` / `dim` / `dim` |
| `style.progressbar.playing` / `style.progressbar.paused` | バーの塗り + ▶︎/⏸ のアクセント | `green` / `yellow` |
| `style.progressbar.style` | プログレスバーの文字 | `blocks` |
| `style.output` | 出力デバイス | `dim` |

プログレスバーの文字は `style.progressbar.style` で決まります: `blocks`
`██████░░░░` · `wave` `~~~~~~----` · `line` `━━━━━━────` · `dots`
`●●●●●●○○○○`、または「塗り + 空き」を意味する任意の 2 文字（`"#-"` →
`######----`）。音量アイコン（`style.volume.icon`）は `auto`（レベルに応じて
🔈/🔉/🔊）、`none`（非表示）、または `♪` のような任意のグリフで、ミュート中は
常に 🔇 が表示されます。文字を変えるこの 2 つのキーは色をオフにしていても
効きます。それ以外のキーは `statusline.color` がオンのときに反映されます。

```
/media:config style.track.title "bold cyan"    # 1 パーツだけ設定
/media:config style.track.title reset          # そのパーツだけデフォルトに
/media:config style reset                      # 全部デフォルトに
```

`media.sh config style` を実行すると、全キーの現在値とデフォルトが一覧で
出ます。変更は次のステータスラインの更新で即座に反映され、再起動は不要です。

## ステップ 2 — ラッパースクリプトを作る

以下を `~/.claude/statusline-media.sh` として保存し、実行権限を付けます
（`chmod +x ~/.claude/statusline-media.sh`）:

```bash
#!/bin/bash
# statusline-media.sh — 既存のステータスライン（そのまま）+ 再生情報の行。
input=$(cat)

# ── 1. 既存の statusLine コマンドを、引用符の間にそのまま貼り付けます。
#       settings.json の "statusLine" 配下にある "command" の値を使って
#       ください。もともとステータスラインがなかった場合は EXISTING を
#       空のままにします。
EXISTING=''
if [ -n "$EXISTING" ]; then
  printf '%s' "$input" | bash -c "$EXISTING"
fi

# ── 2. 再生情報（オフのとき / 何も再生していないとき / プラグインが
#       ないときは何も出力しません）。実行のたびにインストール済みの
#       最新バージョンを探すので、プラグインを更新してもラッパーは
#       そのまま動きます。
MEDIA_DIR="$(ls -d "$HOME"/.claude/plugins/cache/claude-media-control/media/*/ 2>/dev/null \
  | awk -F/ '{ print $(NF-1) "\t" $0 }' \
  | sort -t. -k1,1n -k2,2n -k3,3n \
  | tail -1 | cut -f2-)"
if [ -n "$MEDIA_DIR" ] && [ -x "${MEDIA_DIR}scripts/media.sh" ]; then
  np="$("${MEDIA_DIR}scripts/media.sh" statusline 2>/dev/null)"
  [ -n "$np" ] && printf '%s\n' "$np"
fi
exit 0
```

チェックアウトから開発している場合（`claude --plugin-dir`）は、`MEDIA_DIR`
のブロックをリポジトリのパスに置き換えてください:
`np="$(/path/to/claude-media-control/scripts/media.sh statusline 2>/dev/null)"`

## ステップ 3 — settings.json をラッパーに向ける

`~/.claude/settings.json` で:

```json
{
  "statusLine": {
    "type": "command",
    "command": "\"$HOME/.claude/statusline-media.sh\""
  }
}
```

**ライブ感のあるステータスラインにしたいなら**、`"command"` の隣に
`"refreshInterval": 1` を足すのがおすすめです。ステータスラインは本来、
会話イベントのときにしか更新されないため、何もしていない間は経過時間も
プログレスバーも止まったままです。`refreshInterval` を指定するとコマンドが
定期的に再実行されます。最小値の `1` はセグメントの 1 秒キャッシュとうまく
噛み合い、時間とバーが毎秒動きます。再描画を減らしたければ外すか値を
大きくしてください（再描画のたびに既存のステータスラインコマンドも一緒に
実行されます）。

## メンテナンスのヒント

- ラッパーの `EXISTING` に入っているのは、以前のステータスラインコマンドの
  **コピー**です。あとでステータスラインの構成を変えたら、この行も忘れずに
  更新してください。
- 全部元に戻すには: `settings.json` の `"statusLine"` を元の値に戻し、
  `~/.claude/statusline-media.sh` を削除します。プラグインをアンインストール
  するだけでもセグメントは自然に消えます（プラグインがなければラッパーは
  何も出力しません）が、ラッパーファイル自体は自分で消してください。
- `/media:config display.statusline off` は即座に効きます。オフにした瞬間に
  キャッシュ済みの行が削除されるので、ステータスラインの再起動は不要です。
