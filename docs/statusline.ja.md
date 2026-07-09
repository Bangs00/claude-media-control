# ステータスラインに now-playing を表示する

[English](statusline.md) | [한국어](statusline.ko.md) | **日本語** | [简体中文](statusline.zh-CN.md)

Claude Code のステータスラインに、現在のトラックを追加の行として表示します:

```
[既存のステータスライン、そのまま]
▶︎ Karma Police — Radiohead  ██████░░░░  2:13/4:24
```

このセグメントは `media.sh statusline` が出力します。小さな TTL キャッシュ
（デフォルト 1 秒）から 50ms を大きく下回る速さで応答するため、ステータス
ラインを遅くすることはありません。実際の now-playing 読み取りは TTL
ウィンドウごとに最大 1 回だけ実行されるので、ステータスラインが再描画される
たびに、経過時間とプログレスバーはおよそ 1 秒刻みで進みます。

## 設計上の保証（安心して追加できる理由）

1. 既存のステータスラインコマンドは**置き換えられません** — ラッパーが
   まずそれを、元のまま実行します。
2. その出力は**バイト単位で無加工のまま**通過します。
3. now-playing は常に**独立した行として追記されるだけ**です。
4. `display.statusline` がオフ（デフォルト）の場合、セグメントコマンドは
   何も出力しません — 空行すらありません。Claude Code は存在しない行を
   畳んでくれるため、ステータスラインは以前とまったく同じ見た目になります。

プラグインが `settings.json` を勝手に編集することはありません。以下の手順は
すべて手動で行う、元に戻せる編集です。

## ステップ 1 — セグメントを有効化する

Claude Code 内で:

```
/media:config display.statusline on
```

（有効化の際、まず動作する now-playing 読み取り経路を検証します。拒否された
場合は `/media:doctor` を実行してください。）

### セグメントに表示する内容を選ぶ

`/media:statusline` を実行して、表示する項目とレイアウトを選びます:

- **項目**（自由に組み合わせ可能）: `track`（▶︎ タイトル — アーティスト）、
  `progressbar`（`██████░░░░`）、`time`（`2:13/4:24`）、`spectrum`
  （ライブ周波数バー）。すべて選べば全部表示されます。
- **レイアウト**: 1 行、またはグループごとに行を分ける
  （`statusline.multiline`）。

全項目を 1 行で:

```
▶︎ Karma Police — Radiohead  ██████░░░░  2:13/4:24  ▂▄▆█▇▅▃▂
```

複数行（`statusline.multiline on`）:

```
▶︎ Karma Police — Radiohead
██████░░░░  2:13/4:24
▂▄▆█▇▅▃▂
```

`spectrum` 項目はオプトインで、`display.spectrum on` とシステムオーディオ
録音権限が必要です（`/media:spectrum` を参照）。更新のたびに約 0.5 秒の
オーディオをキャプチャするため他の項目より重めです — 最も軽いステータス
ラインにしたい場合は外してください。

### 色

セグメントはデフォルトでスタイル付きです — Claude Code のステータスラインは
ANSI コードをレンダリングし、下記のラッパーはそれを無加工で通します:

- アイコンとプログレスバーの塗り部分は再生状態に追従
  （再生中は green、一時停止中は yellow）
- **太字**のタイトル、*斜体*のアーティスト、薄表示の時間と空のバーセル
- スペクトラムバーは `spectrum.style` に従って着色:
  - `solid`（デフォルト）— すべてのバーを単色で。色は `spectrum.color` で
    選択（`red green yellow blue magenta cyan white`、デフォルト `cyan`）
  - `rainbow` — バーの位置による固定の前から後ろへの色サイクル
    （音量には決して連動しません）。1 秒ごとに 1 ステップ進みます。
    `spectrum.color` は無視されます

```
/media:config spectrum.style rainbow
/media:config spectrum.color magenta
```

標準の 16 色 SGR コードのみを使うため、すべての色はターミナル自身の
パレットに従います。プレーンテキストがよければ
`/media:config statusline.color off` を実行してください — `NO_COLOR`
環境変数も尊重されます。

## ステップ 2 — ラッパースクリプトを作成する

`~/.claude/statusline-media.sh` として保存し、実行可能にします
（`chmod +x ~/.claude/statusline-media.sh`）:

```bash
#!/bin/bash
# statusline-media.sh — 既存のステータスライン（そのまま）+ now-playing 行。
input=$(cat)

# ── 1. 既存の statusLine コマンドを、引用符の間にそのまま貼り付ける。
#       settings.json の "statusLine" 配下の "command" の値から取ること。
#       以前ステータスラインがなかった場合は EXISTING を空のままにする。
EXISTING=''
if [ -n "$EXISTING" ]; then
  printf '%s' "$input" | bash -c "$EXISTING"
fi

# ── 2. now-playing（オフ / 再生なし / プラグインなしの場合は空出力）。
#       実行時にインストール済みの最新プラグインバージョンを解決するため、
#       ラッパーはプラグイン更新後も動き続ける。
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
ブロックをリポジトリのパスに置き換えてください:
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

**ライブ感のあるステータスラインにするための推奨:** `"command"` の隣に
`"refreshInterval": 1` を追加してください。ステータスラインは通常、会話
イベント時にしか更新されないため、何もしていない間は経過時間とプログレス
バーが止まります。`refreshInterval` はコマンドを定期的に再実行します。
`1`（最小値）はセグメントの 1 秒キャッシュと噛み合い、時間とバーが毎秒
進みます。再描画を減らしたい場合は外すか値を上げてください（再描画のたびに
既存のステータスラインコマンドも再実行されます）。

## メンテナンスに関する注意

- ラッパーは以前のステータスラインコマンドの**コピー**を `EXISTING` に
  保持します。後でステータスライン構成を変えた場合は、この行も更新して
  ください。
- すべて元に戻すには: `settings.json` の以前の `"statusLine"` 値を復元し、
  `~/.claude/statusline-media.sh` を削除します。プラグインをアンインストール
  するだけでもセグメントは自然に消えます（プラグインがなければラッパーは
  何も出力しません）が、ラッパーファイル自体の削除はあなたの手で行って
  ください。
- セグメントは `/media:config display.statusline off` を即座に反映します —
  無効化時にキャッシュ済みの行が削除されるため、ステータスラインの再起動は
  不要です。
