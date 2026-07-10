# claude-media-control

[![CI](https://github.com/Bangs00/claude-media-control/actions/workflows/ci.yml/badge.svg)](https://github.com/Bangs00/claude-media-control/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![macOS](https://img.shields.io/badge/platform-macOS-black)
![Claude Code plugin](https://img.shields.io/badge/Claude%20Code-plugin-d97757)
![Zero dependencies](https://img.shields.io/badge/dependencies-zero-brightgreen)

[English](README.md) | [한국어](README.ko.md) | **日本語** | [简体中文](README.zh-CN.md)

Spotify、Apple Music、ブラウザ、VLC ——**Mac でいま何が再生されていても**、
Claude Code からそのまま確認・操作できます。「今かかってる曲は？」と聞く、
「音楽を一時停止して」と頼む、インタラクティブなリモコンを開く——ぜんぶ
できます。OAuth も API キーもアプリごとの連携設定も要りません。**Homebrew で
インストールするものもありません**。

![claude-media-control のデモ](docs/demo.ja.gif)

## このプラグインならではの点

既存の Claude 向け Spotify / Apple Music 連携は、どれも特定のアプリ専用で、
OAuth や AppleScript のセットアップが前提です。このプラグインは **macOS の
システム全体の now-playing サービス**と直接やり取りするため、どのアプリで
再生していても、*いまアクティブな*プレイヤーをそのまま認識して操作できます。
サードパーティ依存もゼロ。必要なのは Xcode Command Line Tools だけで、
`git clone` が使える環境なら、まず間違いなくインストール済みです
（[要件](#要件)を参照）。

## インストール

Claude Code の中で 2 行だけ。Homebrew の手順はありません:

```
/plugin marketplace add Bangs00/claude-media-control
/plugin install media@claude-media-control
```

最初に media コマンドを実行したときに、小さな native helper を一度だけ
ビルドします（約 2 秒）。以降はキャッシュが使われます。macOS 専用です。

## 使い方

自然言語でも、slash command でも、インタラクティブメニューでも操作できます:

| こう話しかけると | …またはこれを実行 | どうなるか |
| --- | --- | --- |
| 「今かかってる曲は？」 | `/media:now` | 曲名 / アーティスト / アプリ + プログレスバーを表示 |
| 「音楽を止めて」 | `/media:pause` · `/media:toggle` | 再生中のプレイヤーを一時停止 / 再開 |
| 「次の曲にして」 | `/media:next` · `/media:prev` | 次の曲 / 前の曲 |
| 「1:30 に飛ばして」 | `/media:seek 1:30` | 指定した位置へシーク |
| 「アルバムアートを見せて」 | `/media:artwork` | ジャケット画像を保存して表示 |
| 「音量を下げて」 | `/media:volume 30` | システム音量の確認 / 変更（0–100） |
| 「さっき流れてた曲は？」 | `/media:history` | 最近再生された曲の一覧（ローカル記録） |
| 「AirPods で流して」 | `/media:output airpods` | オーディオ出力デバイスの確認 / 切り替え |
| 「リモコンを出して」 | `/media:menu` | 矢印キーで操作するインタラクティブコントローラ |
| 「ステータスラインの並びを変えて」 | `/media:statusline` | プレビューでレイアウトを選ぶか、数字パターンで行と並び順を自由に構成 |
| 「曲名をシアンにして」 | `/media:style` | ステータスラインの項目別スタイル——パーツごとの太字/斜体/色、プログレスバーの文字、音量アイコン |
| 「ステータスラインを設定して」 | `/media:config` | インタラクティブな設定——レイアウトに加え、すべての表示機能のオン / オフ（プログレスバー、履歴、色、マーキー） |
| — | `/media:doctor` | ビルド / 権限 / フォールバックの診断 |

ステータスラインに再生中の曲を出すこともできます——
[docs/statusline.ja.md](docs/statusline.ja.md) を参照してください。
`/media:statusline` はレイアウト例を**プレビューで見せながら**選ばせて
くれて、どの項目を（曲情報、アプリ、音量、プログレスバー、時間、出力
デバイス）どの順序で、どの行に出すかまで決められます。プリセット（Standard
/ Stacked）が合わなければ `Custom…` で `123/456` のような数字パターンを
チャット入力欄にそのまま打つだけです — 数字が項目、`/` が改行、数字の並びが
そのまま表示順になります。項目は保存した順序どおりに描画されるので、「時間を
先頭に」「出力デバイスを前に」といった指定もそのまま反映されます。音量の
項目はアイコン + 音量に応じた高さのバー + パーセント（`🔉 ▄ 45%`）で表示
され、出力デバイスのアイコンはデバイスの種類に合わせて（`🎧` Bluetooth、
`📺` HDMI、`📶` AirPlay、`🔊` スピーカー）変わります。30 セルより長い
タイトルはマーキー式にスクロールし（`statusline.marquee`）、セグメントは
最初から ANSI スタイル付きで出力されます——再生状態で色が変わるアイコンと
プログレスバー、太字の曲名と経過時間、斜体のアーティスト。プレーンテキスト
に戻したいときは `/media:config statusline.color off` を実行してください
（`NO_COLOR` 環境変数も有効です）。さらに `/media:style` を使えば、どの
パーツも個別にスタイリングできます——曲名・アーティスト・アプリ・時間・
音量バーとパーセント・出力デバイスの太字/斜体/色、プログレスバーの
再生/一時停止色と文字（`wave` `~~~~--`、`line`、`dots`、任意の 2 文字）、
音量アイコン（`♪`、非表示、またはレベル連動のデフォルト）まで。各キーは
`reset` で個別にデフォルトへ戻せて、`/media:config style reset` なら全部
まとめて戻ります。

## 仕組み

macOS には、他のアプリの再生情報を読み取る公開 API がありません。非公開の
`MediaRemote` フレームワークにはその機能がありますが、macOS 15.4 以降、
このデーモンは Apple が署名したプロセスにしか応答しません。そこでこの
プラグインは
[ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter)
と同じ手法を使っています。小さな Objective-C ヘルパー
（`native/adapter.m`）を、Apple のプラットフォームバイナリである
`/usr/bin/perl` にロードさせることで、entitlement チェックを通過する仕組み
です。再生操作とシークも同じ経路で処理します。

native helper をビルドできない環境では（Command Line Tools がない場合）、
読み取りはコンパイル不要の `osascript`/JXA に、Spotify と Apple Music の
操作はアプリごとの AppleScript にフォールバックします。いまどのモードで
動いているかは `/media:doctor` が教えてくれます。

> **免責事項。** このプラグインは**非公開かつドキュメント化されていない
> Apple のフレームワーク**に依存しています。現時点では macOS 26.x で動作し、
> macOS アップデートのたびに自動で再検証されます（ビルドキャッシュは OS の
> ビルド番号がキー）が、Apple がいつ仕様を変えたり塞いだりしても不思議は
> ありません。その場合、プラグインはフォールバック経路に切り替わって動作を
> 続け、`/media:doctor` が状況を報告します。無保証です——[LICENSE](LICENSE)
> を参照してください。

## 再生履歴と出力デバイス

`/media:history` は最近再生された曲を新しい順に一覧表示します。記録は
どのみち行われる読み取り（ステータスラインの更新、`/media:now`、再生
コマンド）に**相乗りして**残るため、バックグラウンドのポーリングもデーモンも
追加のリソース負荷もありません。ログはプラグインのデータディレクトリに
最新 500 曲まで保存され、マシンの外に出ることは決してありません。
`/media:config history.record off` で記録を止め、`/media:history clear` で
消去できます。

`/media:output` はオーディオ出力デバイスの一覧表示と切り替えを行います
（「AirPods で流して」）——公開の CoreAudio API を使うので追加の権限は
不要です。ステータスラインに現在のデバイスを出すこともできます:
`/media:config` で「出力デバイス項目」にチェックを入れるか、
`/media:statusline` で好きな位置に配置してください。

## 要件

- **macOS**（macOS 26.x / Apple Silicon でテスト済み。この手法は 15.4 以降が
  対象です）。ほかの OS はロードマップにあります。
- **Xcode Command Line Tools**——初回の native ビルドに必要です。
  `xcode-select --install` でインストールできますが、おそらくもう入って
  います。プラグインの取得に必要な `git` が、`clang` と同じ Command Line
  Tools に含まれているからです。なくてもプラグインはフォールバックモードで
  動きます。

Homebrew も Node も Python も API キーも要りません。

## インストールの確認

```
/media:doctor
```

正常にインストールできていれば `verdict: PRIMARY OK` で終わります。
`DEGRADED` と出た場合は、レポートが対処法を教えてくれます（たいていは
`xcode-select --install` してから `/media:doctor --rebuild`）。

## トラブルシューティング

| 症状 | 対処 |
| --- | --- |
| `DEGRADED — native helper unavailable` | `xcode-select --install` のあと `/media:doctor --rebuild` |
| macOS アップデート後に `PRIMARY READ LIKELY BLOCKED` | `/media:doctor --rebuild`。直らなければ [issue を立ててください](https://github.com/Bangs00/claude-media-control/issues) |
| AppleScript の操作が **error -1743** で失敗する | システム設定 → プライバシーとセキュリティ → オートメーションでターミナルアプリを許可（フォールバックモードのみ） |
| 何も再生していないのに `now` が曲を表示する | アプリが古い状態を報告しています。`/media:next` を試すか、プレイヤーを再起動してください |

ビルドログは `${CLAUDE_PLUGIN_DATA}/build.log` にあります。

## アンインストール

```
/plugin uninstall media@claude-media-control
/plugin marketplace remove claude-media-control
```

これで**マシンはインストール前の状態に完全に戻ります。** プラグインが作る
ものはすべて、Claude が管理する 2 つのディレクトリ
（`~/.claude/plugins/cache/...` と `~/.claude/plugins/data/...`）の中だけに
あり、アンインストール時にどちらも削除されます。LaunchAgent も、ログイン
項目も、ホームディレクトリに残るファイルも、`settings.json` の書き換えも、
システムパッケージもありません。プラグインがそれ以外の場所に書き込むことは
なく、一時的なジャケット画像は `$TMPDIR` に置かれて macOS が自動で消します。

プラグインのファイルではないため残ることがあるものが 2 つあります
（どちらも無害です）:

- AppleScript フォールバックを使った場合、macOS は**オートメーションの許可**
  （「ターミナル → Spotify/Music」）をシステムの権限データベースに残します。
  消したければ `tccutil reset AppleEvents` を実行してください。
- ステータスラインのラッパーを追加していた場合は、
  `~/.claude/statusline-media.sh` を削除し、`settings.json` の
  `"statusLine"` を元の値に戻してください。

## ロードマップ

- **Linux** 対応——`playerctl`/MPRIS ベース。ディスパッチャはすでに OS ごとの
  バックエンド構成になっています。コントリビューション歓迎。
- **Windows** 対応——SMTC（`GlobalSystemMediaTransportControls`）ベース。
  コントリビューション歓迎。

## 開発

```bash
claude --plugin-dir .          # チェックアウトからプラグインをロード
shellcheck scripts/*.sh        # lint
npx bats tests/media.bats      # ユニットテスト（native はスタブ化）
claude plugin validate . --strict
```

CI では上記すべてに加えて、macOS ランナーで strict モードの native ビルドも
実行しています。

## ライセンス

[MIT](LICENSE) です。native adapter は ungive/mediaremote-adapter の
BSD-3-Clause の手法を移植し、ungive/media-control の CLI/JSON の慣例を
参考にしています——[native/NOTICE](native/NOTICE) を参照してください。
