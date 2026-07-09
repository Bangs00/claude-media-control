# claude-media-control

[![CI](https://github.com/Bangs00/claude-media-control/actions/workflows/ci.yml/badge.svg)](https://github.com/Bangs00/claude-media-control/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![macOS](https://img.shields.io/badge/platform-macOS-black)
![Claude Code plugin](https://img.shields.io/badge/Claude%20Code-plugin-d97757)
![Zero dependencies](https://img.shields.io/badge/dependencies-zero-brightgreen)

[English](README.md) | [한국어](README.ko.md) | **日本語** | [简体中文](README.zh-CN.md)

**Mac で再生中のあらゆるメディア** — Spotify、Apple Music、ブラウザ、VLC — を
Claude Code から直接確認・操作できます。「今流れている曲は？」と尋ねる、
「音楽を一時停止して」と頼む、あるいはインタラクティブなリモコンを開く —
すべて可能です。OAuth も API キーもアプリごとの連携も不要で、**Homebrew での
インストールも一切ありません**。

![claude-media-control デモ](docs/demo.ja.gif)

## このプラグインを選ぶ理由

既存の Claude/Spotify/Apple Music 連携は、それぞれ 1 つのアプリに縛られ、
OAuth や AppleScript のセットアップが必要です。このプラグインは **macOS の
システム全体の now-playing サービス**と通信するため、どのアプリであっても
*現在アクティブな*プレイヤーを認識・操作でき、**サードパーティ依存はゼロ**
です。唯一の要件は Xcode Command Line Tools ですが、`git clone` ができる環境
ならすでにインストール済みのはずです（[要件](#要件)を参照）。

## インストール

Claude Code 内で 2 行だけ — Homebrew の手順はありません:

```
/plugin marketplace add Bangs00/claude-media-control
/plugin install media@claude-media-control
```

最初の media コマンド実行時に小さな native helper をビルドします（約 2 秒、
初回のみ）。以降はキャッシュが使われます。macOS 専用です。

## 使い方

自然言語、slash command、インタラクティブメニューのいずれでも操作できます:

| こう言うと | …または実行 | 動作 |
| --- | --- | --- |
| 「今流れている曲は？」 | `/media:now` | 現在のタイトル / アーティスト / アプリ + プログレスバー |
| 「音楽を止めて」/ "pause the music" | `/media:pause` · `/media:toggle` | アクティブなプレイヤーを一時停止 / 再開 |
| 「次の曲」 | `/media:next` · `/media:prev` | 次へ / 前へ |
| 「1:30 にジャンプして」 | `/media:seek 1:30` | 絶対位置へシーク |
| 「アルバムアートを見せて」 | `/media:artwork` | カバーを保存して表示 |
| 「オーディオスペクトラムを見せて」 | `/media:spectrum` | 再生中オーディオのライブ周波数バー（オプトイン） |
| 「音量を下げて」 | `/media:volume 30` | システム出力音量の取得 / 設定（0–100） |
| 「リモコンをちょうだい」 | `/media:menu` | インタラクティブコントローラ（矢印キーメニュー） |
| — | `/media:statusline` | now-playing ステータスラインの表示項目 + レイアウトを選択 |
| — | `/media:config` | 表示機能の切り替え（プログレスバー、ステータスライン、スペクトラム） |
| — | `/media:doctor` | ビルド / 権限 / フォールバックの診断 |

オプション: ステータスラインに now-playing を表示できます —
[docs/statusline.ja.md](docs/statusline.ja.md) を参照してください。表示する
項目（track、progress bar、time、spectrum）と、グループごとに行を分けるか
どうかは `/media:statusline` で選べます。セグメントは ANSI スタイル付きで
出力されます — 再生状態に応じた色のアイコンとプログレスバー、太字のタイトル、
斜体のアーティスト、色付きのスペクトラム（単色、または `spectrum.style` に
よる位置ベースのレインボー）。`/media:config statusline.color off`（または
`NO_COLOR`）でプレーンテキストに戻せます。

## 仕組み

macOS には他アプリの now-playing 情報を読む公開 API がありません。非公開の
`MediaRemote` フレームワークにはその機能がありますが、macOS 15.4 以降、その
デーモンは Apple が署名したプロセスにしか応答しません。このプラグインは
[ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter)
と同じ手法を使います: 小さな Objective-C ヘルパー（`native/adapter.m`）を、
Apple プラットフォームバイナリである `/usr/bin/perl` がロードすることで
entitlement チェックを通過します。再生コマンドとシークも同じ経路を使います。

native helper がビルドできない場合（Command Line Tools がない場合）は、
`osascript`/JXA によるコンパイル不要の読み取りにフォールバックし、Spotify と
Apple Music の操作はアプリごとの AppleScript にフォールバックします。現在の
モードは `/media:doctor` で確認できます。

> **免責事項。** このプラグインは**非公開・非公式の Apple フレームワーク**に
> 依存しています。現在 macOS 26.x で動作し、macOS アップデートのたびに自動で
> 再検証されます（ビルドキャッシュは OS ビルド番号をキーにしています）が、
> Apple はいつでもこれを変更・遮断する可能性があります。その場合、プラグインは
> フォールバック経路にデグレードし、`/media:doctor` がそれを報告します。
> 無保証です — [LICENSE](LICENSE) を参照してください。

## オーディオスペクトラム（オプトイン）

`/media:spectrum` は再生中のオーディオをライブ周波数バーで表示します:

```
63Hz ▂▄▆█▇▅▃▂ ▃▂▁▁ ▁ 16kHz   (peak: 1.2kHz)
```

`--live <seconds>` で複数フレームをストリーミングでき、`/media:statusline` で
ステータスラインにミニスペクトラムを追加できます。

バーは `spectrum.color`（デフォルト cyan）で色付けされます — または
`/media:config spectrum.style rainbow` で、バーの位置による前から後ろへの
色サイクルに設定できます（意図的に音量ベースにはしていません）。色は
ステータスラインとターミナルでの直接実行時に表示され、チャットの返信は
プレーンなグリフのままです。

**オーディオのキャプチャ方法。** Core Audio の *process tap*
（`AudioHardwareCreateProcessTap`、macOS 14.4 から公開 API）がシステム出力
ミックスを読み取り、ローカルの Accelerate/vDSP FFT が帯域に変換します。
**オーディオがマシンの外に出ることはありません** — 生成されるのはバー文字列
だけで、何も録音・送信されません。

**デフォルトはオフ。** 音楽操作プラグインがオーディオ録音権限を求めるのは
警戒されて当然なので、スペクトラムはオプトインです:

```
/media:config display.spectrum on
```

**権限。** tap にはターミナルアプリへの*システムオーディオ録音*権限が必要
です。macOS はコマンドラインツールに自動プロンプトを表示**しない**ため、
手動で付与してください: システム設定 > プライバシーとセキュリティ >
画面収録とシステムオーディオ録音で、オーディオを再生しながらターミナル
（Terminal、iTerm など）を有効にします。有効化はフェイルクローズドです —
オーディオ再生中にもかかわらずキャプチャが無音の場合は拒否し、不足している
権限を案内します。後で権限が取り消されると機能は自動的に無効化されます。
権限の状態は `/media:doctor` が報告します。

macOS 14.4 以降が必要です。それより古いシステムでは機能は非表示のままで、
ヘルパーもコンパイルされません。

## 要件

- **macOS**（macOS 26.x / Apple Silicon でテスト済み。この手法は 15.4 以降が
  対象）。他の OS はロードマップにあります。
- **Xcode Command Line Tools** — 初回の native ビルド用。
  `xcode-select --install` でインストールできます。プラグインの clone に
  必要な `git` は `clang` と同じ Command Line Tools に含まれるため、ほぼ
  確実にインストール済みです。なくてもプラグインはフォールバックモードで
  動作します。

Homebrew、Node、Python、API キーはいずれも不要です。

## インストールの確認

```
/media:doctor
```

正常なインストールは `verdict: PRIMARY OK` で終わります。`DEGRADED` の場合、
レポートが対処法を示します（通常は `xcode-select --install` のあと
`/media:doctor --rebuild`）。

## トラブルシューティング

| 症状 | 対処 |
| --- | --- |
| `DEGRADED — native helper unavailable` | `xcode-select --install` のあと `/media:doctor --rebuild` |
| macOS アップデート後の `PRIMARY READ LIKELY BLOCKED` | `/media:doctor --rebuild`。解消しない場合は [issue を作成](https://github.com/Bangs00/claude-media-control/issues)してください |
| AppleScript 操作が **error -1743** で失敗 | システム設定 → プライバシーとセキュリティ → オートメーションでターミナルアプリを承認（フォールバックモードのみ） |
| 何も再生していないのに `now` がトラックを表示 | アプリが古い状態を報告しています。`/media:next` を試すかプレイヤーを再起動してください |
| スペクトラムが無音、または `display.spectrum on` が拒否される | システム設定 → プライバシーとセキュリティでターミナルアプリに**システムオーディオ録音**を許可（オーディオ再生中に）してから再試行。状態は `/media:doctor` で確認できます |

ビルドログは `${CLAUDE_PLUGIN_DATA}/build.log` にあります。

## アンインストール

```
/plugin uninstall media@claude-media-control
/plugin marketplace remove claude-media-control
```

これで**マシンはインストール前の状態に完全に戻ります。** プラグインが作成
するものはすべて Claude が管理する 2 つのディレクトリ
（`~/.claude/plugins/cache/...` と `~/.claude/plugins/data/...`）にあり、
どちらもアンインストール時に削除されます — LaunchAgent なし、ログイン項目
なし、ホームディレクトリのファイルなし、`settings.json` の編集なし、
システムパッケージなし。プラグインがそれ以外の場所に書き込むことはありません。
一時的なアートワークは `$TMPDIR` に置かれ、macOS が自動的に消去します。

プラグインのファイルではないため残る可能性があるものが 2 つあります
（どちらも無害です）:

- AppleScript フォールバックを使った場合、macOS は**オートメーション承認**
  （「ターミナル → Spotify/Music」）をシステムの権限データベースに保持します。
  必要なら `tccutil reset AppleEvents` で消去できます。
- オプションのステータスラインラッパーを追加した場合は、
  `~/.claude/statusline-media.sh` を削除し、`settings.json` の以前の
  `"statusLine"` 値を復元してください。

## ロードマップ

- ~~**オーディオスペクトラム**（`/media:spectrum`）~~ — v0.2.0 で提供済み
  （上記参照）。
- **Linux** バックエンド — `playerctl`/MPRIS 経由。ディスパッチャはすでに
  OS ごとのバックエンド構造になっています。コントリビューション歓迎。
- **Windows** バックエンド — SMTC（`GlobalSystemMediaTransportControls`）
  経由。コントリビューション歓迎。

## 開発

```bash
claude --plugin-dir .          # チェックアウトからプラグインをロード
shellcheck scripts/*.sh        # lint
npx bats tests/media.bats      # ユニットテスト（native はスタブ化）
claude plugin validate . --strict
```

CI は上記すべてに加え、macOS ランナーでの strict native ビルドを実行します。

## ライセンス

[MIT](LICENSE)。native adapter は ungive/mediaremote-adapter の BSD-3-Clause
の手法を移植し、ungive/media-control の CLI/JSON 規約を参照しています —
[native/NOTICE](native/NOTICE) を参照してください。
