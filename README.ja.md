# claude-media-control

[![CI](https://github.com/Bangs00/claude-media-control/actions/workflows/ci.yml/badge.svg)](https://github.com/Bangs00/claude-media-control/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![macOS](https://img.shields.io/badge/platform-macOS-black)
![Claude Code plugin](https://img.shields.io/badge/Claude%20Code-plugin-d97757)
![Zero dependencies](https://img.shields.io/badge/dependencies-zero-brightgreen)

[English](README.md) | [한국어](README.ko.md) | **日本語** | [简体中文](README.zh-CN.md)

**いま流れている曲を、Claude Code のステータスラインにライブで** — 毎秒
動き、⌘+クリックで操作でき、バーの文字ひとつまで好みに合わせられます:

```
▶︎ Karma Police — Radiohead (Spotify)  🔉 ▄ 45%
━━━━━━━━━━━━────────  2:13/4:24  🎧 AirPods Pro
```

Mac で再生中のものなら何でも — Spotify、Apple Music、ブラウザのタブ、
VLC — チャットからも操作できます:「今かかってる曲は？」「一時停止して」
「次の曲」「AirPods で流して」。**macOS のシステム全体の now-playing
サービス**と直接やり取りするので、特定アプリへのロックインも、OAuth も
API キーも不要 — Homebrew でインストールするものもありません。

![claude-media-control のデモ](docs/demo.ja.gif)

## クイックスタート

Claude Code の中で:

```
/plugin marketplace add Bangs00/claude-media-control
/plugin install media@claude-media-control
/media:config display.statusline on
```

最後の行がステータスラインです — 配線まで自動で終わり、次の更新から
表示されます。macOS 専用。最初の media コマンドで小さな native helper を
一度だけビルドします（約 2 秒）。インストールの確認は `/media:doctor`
（正常なら `verdict: PRIMARY OK`）。

## ステータスライン

以下はぜんぶ自動です — 詳しいガイドは
[docs/statusline.ja.md](docs/statusline.ja.md):

- **安全な配線。** 有効にすると、セグメントは既存のステータスラインの
  あとに独立した行として付け加わります — 既存分は 1 バイトも変わらず
  動き続けます。以前の `statusLine` 値はバックアップされ、**プラグインを
  アンインストールすれば自動で復元されます**。再起動も手作業もなし。
- **⌘+クリックで操作**（iTerm2、Ghostty、WezTerm、Kitty、VS Code など）:
  ▶︎/⏸ アイコンで再生 / 一時停止、曲名で再生中のブラウザタブや Music の
  トラックへジャンプ、プログレスバーはマスごとにその位置へシーク。
  非対応のターミナルでは、ただの通常セグメントとして表示されます。
- **数字パターンで配置** — `/media:statusline` で: 数字が項目 —
  1 曲情報 · 2 アプリ · 3 音量 · 4 バー · 5 時間 · 6 出力デバイス — で、
  `/` が改行。`123/456` なら曲 / アプリ / 音量の下にバー / 時間 / 出力が
  重なります。
- **パーツごとのスタイル**: 再生 / 一時停止のアクセントカラー、パーツ
  ごとの太字 / 斜体 / 色（色名または `#ff8800` のような hex コード）、
  プログレスバー文字 29 種（デフォルトの `line`
  `━━──` から `smooth` の部分ブロック、`knob` のスライダーつまみ、長さに
  適応する `wave`/`pulse`/`eq`/`notes` 波形、オーディオビジュアライザーの
  `spectrum`/`mirror`/`cava`/`ripple` まで）、バーの長さ（1〜60 マス）、
  音量バーの形、アイコン — そして `off` でどのパーツでも非表示に。
  **実例つきの全カタログは
  [スタイルギャラリー](docs/styles.ja.md)へ。完成ルックを丸ごと貼るなら
  [レシピ集](docs/recipes.ja.md)。**

## チャットから操作する

自然言語でも、slash command でも、インタラクティブメニューでも:

| こう話しかけると | …またはこれを実行 | どうなるか |
| --- | --- | --- |
| 「今かかってる曲は？」 | `/media:now` | 曲名 / アーティスト / アプリ + プログレスバー |
| 「音楽を止めて」 | `/media:pause` · `/media:toggle` | 一時停止 / 再開 |
| 「次の曲にして」 | `/media:next` · `/media:prev` | 次の曲 / 前の曲 |
| 「1:30 に飛ばして」 | `/media:seek 1:30` | 指定位置へシーク |
| 「アルバムアートを見せて」 | `/media:artwork` | ジャケットを保存して表示 |
| 「音量を下げて」 | `/media:volume 30` | システム音量（0–100） |
| 「さっき流れてた曲は？」 | `/media:history` | 最近再生された曲の一覧 |
| 「AirPods で流して」 | `/media:output airpods` | 出力デバイスの確認 / 切り替え |
| 「リモコンを出して」 | `/media:menu` | 矢印キーのインタラクティブ操作 |
| 「曲名をシアンにして」 | `/media:statusline` | ステータスラインの配置 + スタイル |
| 「履歴をオフにして」 | `/media:config` | クイックトグル + ステータスラインのリセット |
| — | `/media:doctor` | ビルド / 権限 / フォールバックの診断 |

再生履歴は**相乗りで**記録されます — どのみち行われる読み取り
（ステータスラインの更新、コマンド）に便乗するので、ポーリングも
デーモンもありません。ログは最新 500 曲までローカルにだけ保存され、
マシンの外には出ません（`/media:config history.record off` で停止、
`/media:history clear` で消去）。出力デバイスの一覧と切り替えは公開の
CoreAudio API 経由 — 追加の権限は不要です。

## 仕組み

macOS には他アプリの再生情報を読む公開 API がなく、非公開の
`MediaRemote` フレームワークは 15.4 以降 Apple 署名のプロセスにしか
応答しません。
[ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter)
と同じ手法で、小さな Objective-C ヘルパー（`native/adapter.m`）を Apple
のプラットフォームバイナリである `/usr/bin/perl` に読み込ませ、
エンタイトルメント検査を通過します。Command Line Tools がなければ、
コンパイル不要の `osascript`/JXA での読み取りと、アプリ別 AppleScript で
の操作（Spotify / Apple Music）に切り替わります。いまどのモードかは
`/media:doctor` が教えてくれます。

> **免責。** このプラグインは**ドキュメント化されていない Apple の
> 非公開フレームワーク**に依存しています。現在は macOS 26.x で動作し、
> macOS アップデートのたびに自動で再検証されますが（ビルドキャッシュは
> OS ビルド番号に紐づく）、Apple はいつでも変更・遮断できます — その
> 場合はフォールバックに切り替わり、`/media:doctor` が報告します。
> 無保証です — [LICENSE](LICENSE) を参照。

## 要件

- **macOS**（26.x / Apple Silicon でテスト。手法は 15.4+ が対象）。
- **Xcode Command Line Tools** — 一度きりのビルド用。`git clone` が
  使えるならもう入っています（なければ `xcode-select --install`。
  なくてもフォールバックモードで動きます）。

Homebrew も、Node も、Python も、API キーも要りません。

## トラブルシューティング

| 症状 | 対処 |
| --- | --- |
| `DEGRADED — native helper unavailable` | `xcode-select --install` のあと `/media:doctor --rebuild` |
| macOS アップデート後に `PRIMARY READ LIKELY BLOCKED` | `/media:doctor --rebuild`。続くようなら [issue を立ててください](https://github.com/Bangs00/claude-media-control/issues) |
| AppleScript の操作が **error -1743** で失敗 | システム設定 → プライバシーとセキュリティ → オートメーションでターミナルを許可（フォールバックモードのみ） |
| 何も再生していないのに `now` に曲が出る | アプリが古い状態を報告しています — `/media:next` を実行するかプレイヤーを再起動 |

ビルドログ: `${CLAUDE_PLUGIN_DATA}/build.log`

## アンインストール

```
/plugin uninstall media@claude-media-control
/plugin marketplace remove claude-media-control
```

これで**マシンはインストール前の状態に完全に戻ります。** すべては Claude
が管理する 2 つのディレクトリ（`~/.claude/plugins/cache/…` と
`…/data/…`）の中だけ — LaunchAgent もログイン項目もシステムパッケージも
ありません。ステータスラインの配線は自分で元に戻ります: アンインストール
後の最初の更新で、wrapper が以前の `statusLine` を復元し、自分自身と
バックアップを削除し、クリックハンドラーアプリも取り除きます —
1 秒以内にステータスラインは元の姿に戻ります
（[詳細](docs/statusline.ja.md)）。

無害なものが 2 つ残ることがあります: AppleScript フォールバックを使った
場合の macOS の**オートメーション許可**の記録（`tccutil reset
AppleEvents` で消去可能）と、ステータスラインを**手動で**配線していた
場合のあなた自身の wrapper ファイル — こちらはご自身で削除してください。

## ロードマップ

- **Linux** は `playerctl`/MPRIS、**Windows** は SMTC ベース —
  ディスパッチャは OS 別バックエンド構造になっています。コントリビュート
  歓迎です。

## 開発

```bash
claude --plugin-dir .          # チェックアウトからプラグインを読み込む
shellcheck scripts/*.sh        # リント
npx bats tests/media.bats      # ユニットテスト（native はスタブ化）
claude plugin validate . --strict
```

CI では上記すべてに加え、macOS ランナーで strict モードの native
ビルドも走ります。

## ライセンス

[MIT](LICENSE) です。native adapter は ungive/mediaremote-adapter の
BSD-3-Clause の手法を移植し、ungive/media-control の CLI/JSON 慣習を
参照しています — [native/NOTICE](native/NOTICE) を参照。
