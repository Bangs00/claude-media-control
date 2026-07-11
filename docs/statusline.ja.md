# ステータスラインに再生中の曲を表示する

[English](statusline.md) | [한국어](statusline.ko.md) | **日本語** | [简体中文](statusline.zh-CN.md)

Claude Code のステータスラインに、いま流れている曲が 1 行加わります:

```
[既存のステータスラインはそのまま]
▶︎ Karma Police — Radiohead (Spotify)  ━━━━━━────  2:13/4:24
```

セグメントは 1 秒 TTL のキャッシュから 50ms 未満で応答するため、
ステータスラインが遅くなることはありません。実際の再生情報の読み取りは
毎秒最大 1 回 — 時間とバーが毎秒動くのも、この周期のおかげです。

## 有効にする

```
/media:config display.statusline on
```

セットアップはこれだけです — 再起動も手作業もありません。
（`/media:statusline` で配置を保存しても同じように有効になります。）
有効化の前に再生情報が実際に読めるかを検証し（拒否されたら
`/media:doctor` を）、それからセグメントを自動で配線します:

1. `~/.claude/settings.json` の現在の `"statusLine"` 値を
   `~/.claude/statusline-media.backup.json` にバックアップします
   （なければ `null`）。
2. `~/.claude/statusline-media.sh` に wrapper を生成します。既存の
   ステータスラインコマンドを先に実行し、そのあとに再生中の行を
   付け加えます。
3. `settings.json` が wrapper を指すようにします。既存エントリのほかの
   キー（`padding` など）はすべて保持され、自分で設定していなければ
   `refreshInterval: 1` が追加されます — この毎秒の再実行があるから、
   何もしていない間も時間とバーが動きます。（再描画を減らしたければ
   値を上げるか外してください。再描画のたびに既存のステータスライン
   コマンドも一緒に実行されます。）

## クリックで操作する

ハイパーリンク対応のターミナルでは、セグメントが **⌘+クリック**に
反応します:

| 対象 | ⌘+クリックの動作 |
| --- | --- |
| `▶︎` / `⏸` アイコン | 再生 / 一時停止の切り替え |
| 曲名 — アーティスト、`(アプリ)` | 再生中のメディアへジャンプ: 再生中のブラウザタブ（Safari、Chrome、Edge、Brave、Vivaldi、Opera）、または Music の現在のトラック — それ以外のアプリは前面に出るだけ |
| プログレスバー | シーク — 10 マスそれぞれがその位置へジャンプ（5%、15%、… 95%） |

- **対応ターミナル**: iTerm2、Ghostty、WezTerm、Kitty、VS Code、
  Alacritty 0.11+（tmux 3.4+ はリンクを素通しします）。ハイパーリンク
  非対応のターミナルでは、ただの通常セグメントとして表示されます。
- クリックの結果は次の更新（1 秒以内）で反映されます: アイコンが替わり、
  バーがジャンプします。
- スイッチ: `/media:config statusline.links off` でリンクなしの通常
  セグメントに戻ります。再度オンにするとハンドラーアプリを再生成し、
  そのビルドが失敗すると拒否されます（exit 3）— 誰も応えないリンクは、
  ないほうがましだからです。
- 最初のタブジャンプ時に一度だけ、オートメーションの許可
  （`ClaudeMediaClick.app`）を求められます — 拒否しても、静かにアプリの
  前面化までは動き続けます。

<details>
<summary>クリックの仕組み（そして安全な理由）</summary>

クリック可能な部分は、ローカルの `claude-media://` URL スキームを指す
OSC 8 ハイパーリンクです。ステータスラインを有効にすると、小さな
ハンドラーアプリ（`ClaudeMediaClick.app` — macOS 標準の `osacompile` で
プラグインのデータディレクトリに生成、サードパーティコードなし）が作られ、
LaunchServices に登録されます。クリックすると `media.sh open-url` が実行
されますが、受け付ける操作はきっかり 3 つ — toggle、activate、パーセント
指定のシーク — だけで、それ以外はすべて拒否します。URL スキームは本来
どのアプリからでも開けるシステム全体の入り口なので、表面をここまで
絞ったことこそが要点です: 再生 / 一時停止、プレイヤーの前面化、シーク —
最悪でも迷惑レベル、キーボードのメディアキーと同じ等級です。

ブラウザでの再生は、Web コンテンツのヘルパープロセスを所有アプリに解決
して前面化し（例: `com.openai.atlas.web` → ChatGPT Atlas）、アプリが
スクリプトに対応していればメディアそのものに着地します: トラック名と
一致するウィンドウ+タブを選択するか、Music の現在のトラックを表示します。
スクリプトインターフェイスのないアプリ（例: ChatGPT Atlas、Spotify）は
前面に出るところまでです。プラグインをアンインストールすると（または
`media.sh statusline uninstall`）、ハンドラーアプリも登録解除されて
削除されます。状態は `/media:doctor` が報告します（`Click links`）。

</details>

## 更新は使っているタブについてくる

Claude Code のセッションを複数開いていても、セグメントは**実際に使って
いるセッションでだけ更新されます** — タイピング、スクロール、そのタブへの
切り替え、すべてが「使っている」に数えられます。ほかのセッションは最後の
行を凍結したまま保ち（曲は表示されたまま、バーと時間だけ止まります）、
戻ってくると 1〜2 更新で追いつきます。もともとのステータスラインは
どのセッションでも生きたまま動き続けます — ゲートがかかるのはプラグインの
行だけです。設定は不要です。

どのセッションでも動いてほしければ:

```
/media:config statusline.activetab off
```

<details>
<summary>ゲートの仕組み</summary>

ステータスラインコマンドは制御 tty なしで実行されるため、セグメントは
プロセスの祖先をたどってセッションのターミナルを握る Claude Code
プロセスを見つけ、各ターミナルの最終入力時刻（`w` が IDLE として表示する
あの atime シグナル）を、プラグインデータディレクトリの小さな状態ファイル
（`statusline.tty` — 内容は現在の保持者のデバイス、mtime は保持者の
ハートビートで、セッションが閉じれば数秒で席を明け渡します）を介して
比較します。生きたレンダリングは毎回ターミナルごとのスナップショット
（`statusline.frozen.<tty>`）も残します — 非アクティブなセッションが
再表示するのはこの行です。自分の tty を持たないセッション（VS Code、
デスクトップアプリ、ヘッドレス実行）は順位付けできないため、競争せずに
常に生きたレンダリングをします。ゲート内のあらゆる失敗はフェイル
オープンです — 壊れたら凍結ではなく、生きた側に倒れます。

</details>

## セグメントの配置

`/media:statusline` がセグメントの見た目を決めるハブです — タブは 3 つ:
**Items**（オン / オフ）、**Layout**（プリセットまたは数字パターン）、
**Style**（[スタイルギャラリー](styles.ja.md)参照）。パターンの凡例:

| # | 項目 | 表示例 |
| --- | --- | --- |
| 1 | `track` | `▶︎ Karma Police — Radiohead` |
| 2 | `app` | `(Spotify)` |
| 3 | `volume` | `🔉 ▄ 45%` — ミュート時は `🔇` |
| 4 | `progressbar` | `━━━━━━────` |
| 5 | `time` | `2:13/4:24` |
| 6 | `output` | `🎧 AirPods Pro` — アイコンはデバイス種別に従う |

数字の並び = 表示順、`/` で改行、抜いた数字の項目は表示されません。
デフォルトは `track app progressbar time` で、リストを直接指定することも
できます:
`/media:config statusline.fields "time,progressbar,track,app"`。

Standard — 全項目を 1 行に（`123456`）:

```
▶︎ Karma Police — Radiohead (Spotify)  🔉 ▄ 45%  ━━━━━━────  2:13/4:24  🎧 AirPods Pro
```

Stacked — 2 行（`123/456`）:

```
▶︎ Karma Police — Radiohead (Spotify)  🔉 ▄ 45%
━━━━━━────  2:13/4:24  🎧 AirPods Pro
```

出力デバイスを曲の行に、音量は抜いて（`126/45`）:

```
▶︎ Karma Police — Radiohead (Spotify)  🎧 AirPods Pro
━━━━━━────  2:13/4:24
```

レイアウトの振る舞い:

- **リストに `/` があるとき**（明示レイアウト）: 各行には置いた項目だけが
  その順に出ます。表示するものがない行は行ごと消えます — 空行は
  できません。
- **`/` がないとき**（グループレイアウト）: 1 行にまとめるか、
  `statusline.multiline on` でグループごとに改行します。グループの規則:
  `app` は track にくっつき、隣り合う `progressbar`+`time` はペアになり、
  `output` / `volume` は隣の track グループに合流します（互いに隣なら
  2 つでペア）。
- `output` と `volume` には native helper が必要です。セグメントが
  もともと行う読み取りに相乗りするので、追加コストはありません。

## スタイリング

セグメントは最初からスタイル付きです: 再生状態に応じた green / yellow の
アクセント、**太字**の曲名と経過時間、*斜体*のアーティスト、控えめに
薄くなるその他 — 標準 16 色の SGR だけを使うので、実際の色味は
ターミナルのパレットが決めます。

すべてのパーツは個別にスタイリングできます — 色、太字 / 斜体、14 種類の
プログレスバー文字、音量バーの形、アイコン、そして `off` で非表示まで。
**カタログ全部と実例、レシピ: [docs/styles.ja.md](styles.ja.md)**

```
/media:config statusline.color off     # プレーンテキストに（NO_COLOR も有効）
/media:config statusline.marquee off   # 長い曲名のスクロールをやめる
```

30 セル（ターミナルの升目）より長い曲名は、固定幅の窓の中を毎秒 1 文字ずつ
マーキー式に流れます（漢字・かな・ハングルは 2 セル換算なので、窓の幅は
一定に保たれます）。

## トグル一覧

| キー（`/media:config …`） | デフォルト | 役割 |
| --- | --- | --- |
| `display.statusline` | `off` | セグメントの表示（オンで配線まで自動） |
| `statusline.fields` | `track,app,progressbar,time` | 項目・順序・`/` 改行 |
| `statusline.multiline` | `off` | グループレイアウトでグループごとに 1 行 |
| `statusline.color` | `on` | ANSI スタイル（`NO_COLOR` が優先） |
| `statusline.marquee` | `on` | 30 セル超の曲名をスクロール |
| `statusline.links` | `on` | ⌘+クリック操作 |
| `statusline.activetab` | `on` | 使用中のタブでだけ更新 |
| `statusline reset` | — | 初期の見た目へ（配置・行・色・marquee・スタイル） |

## 手動セットアップ（カスタムステータスライン）

配線を自分で管理したい — たとえばセグメントを別の行ではなく、自分の
ステータスラインスクリプトの*中に*組み込みたい場合は？ コマンドを**先に**
用意してから有効化してください。自動配線は、すでにセグメントを実行して
いる `statusLine` コマンド（`statusline-media.sh` か `media.sh …
statusline` を含むもの）を認識してそっとしておき、有効化は表示トグルを
切り替えるだけになります。

出発点になる汎用 wrapper — `~/.claude/statusline-media.sh` に保存して
`chmod +x`:

```bash
#!/bin/bash
# statusline-media.sh — 既存のステータスライン（そのまま）+ 再生中の行。
input=$(cat)

# ── 1. 既存の statusLine コマンドを引用符の間にそのまま貼り付けます。
#       settings.json の "statusLine" 配下の "command" 値を持ってきます。
#       もともとステータスラインがなければ EXISTING は空のままに。
EXISTING=''
if [ -n "$EXISTING" ]; then
  printf '%s' "$input" | bash -c "$EXISTING"
fi

# ── 2. 再生中の行（オフ / 何も再生していない / プラグインなし のときは
#       何も出力しません）。実行時にインストール済みの最新バージョンを
#       解決するので、プラグインを更新しても wrapper は動き続けます。
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

つぎに `~/.claude/settings.json` をこのファイルに向けます:

```json
{
  "statusLine": {
    "type": "command",
    "command": "\"$HOME/.claude/statusline-media.sh\"",
    "refreshInterval": 1
  }
}
```

チェックアウトから開発している場合（`claude --plugin-dir`）は、
`MEDIA_DIR` ブロックをリポジトリのパスに置き換えてください:
`np="$(/path/to/claude-media-control/scripts/media.sh statusline 2>/dev/null)"`

## 設計上の保証（安心していい理由）

1. 既存のステータスラインは**置き換えられません** — wrapper が先に実行し、
   その出力は 1 バイトも変わらず通過します。再生中の情報は常に独立した
   行として付け加わるだけです。
2. オフ（デフォルト）のときは何も出力しません — 空行すらありません。
   Claude Code が存在しない行を畳んでくれるので、ステータスラインは
   以前とまったく同じに見えます。
3. `settings.json` で触るキーはちょうど 1 つ — `statusLine` — で、必ず
   以前の値をバックアップしてからです。書き込みはアトミックで、
   シンボリックリンクをたどり（dotfiles 構成も無事）、ほかのキーには
   いっさい触れません。
4. **プラグインをアンインストールすると、すべてが自動で元に戻ります。**
   Claude Code にはアンインストールフックがないため、wrapper は自己修復
   します: プラグインが消えたと分かると、バックアップしておいた
   `statusLine` を復元し、自分自身とバックアップを削除し、クリック
   ハンドラーアプリも取り除きます — アンインストールから 1 秒以内に。
5. プラグインを**無効化**しただけなら、wrapper は何も足さずに待ちます —
   以前のステータスラインがいつもどおり動きます。
6. **手動で**配線したステータスラインは検出され、インストール時も
   アンインストール時も、決して触れられません。

## 配線コマンド

```
media.sh statusline status      # managed | manual | none（/media:doctor にも表示）
media.sh statusline uninstall   # プラグインは残して配線だけ解除:
                                # バックアップを復元、wrapper + バックアップを削除、
                                # display.statusline を off に
```

補足:

- **自動配線（managed）**: wrapper は生成ファイルです — 直接編集しないで
  ください。プラグインの更新時、および `media.sh statusline install` の
  再実行で作り直されます。
- **手動配線（manual）**: ファイルはあなたのものです。プラグインは決して
  触りません。ステータスライン構成を変えたら `EXISTING` 行も更新して
  ください。プラグインを消せばセグメントは自然に沈黙しますが、wrapper の
  削除と `"statusLine"` の復元はご自身で。
- `/media:config display.statusline off` は即時に効きます — オフにした
  瞬間キャッシュ済みの行が消え、配線は残るので再オンも即時です。
