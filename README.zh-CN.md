# claude-media-control

[![CI](https://github.com/Bangs00/claude-media-control/actions/workflows/ci.yml/badge.svg)](https://github.com/Bangs00/claude-media-control/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![macOS](https://img.shields.io/badge/platform-macOS-black)
![Claude Code plugin](https://img.shields.io/badge/Claude%20Code-plugin-d97757)
![Zero dependencies](https://img.shields.io/badge/dependencies-zero-brightgreen)

[English](README.md) | [한국어](README.ko.md) | [日本語](README.ja.md) | **简体中文**

Spotify、Apple Music、浏览器、VLC——**不管 Mac 上正在播放什么**，都能在
Claude Code 里直接查看和控制。问一句"现在放的是什么歌？"，说一声"暂停音乐"，
或者打开一个交互式遥控器。不需要 OAuth，不需要 API 密钥，不需要逐个应用去
配置，**也不需要用 Homebrew 装任何东西**。

![claude-media-control 演示](docs/demo.zh-CN.gif)

## 为什么选择它

现有的 Claude 与 Spotify/Apple Music 的集成，每一个都绑定在单一应用上，
还得先折腾一遍 OAuth 或 AppleScript。这个插件直接和 **macOS 系统级的
now-playing 服务**打交道：不管你用哪个应用放歌，它识别和控制的始终是*当前
正在播放*的那个播放器，而且**零第三方依赖**。唯一的要求是 Xcode Command
Line Tools——只要你的机器能跑 `git clone`，它们就已经装好了（见
[环境要求](#环境要求)）。

## 安装

在 Claude Code 里输入两行就装好了，没有 Homebrew 这一步：

```
/plugin marketplace add Bangs00/claude-media-control
/plugin install media@claude-media-control
```

第一次运行 media 命令时会构建一个很小的 native helper（约 2 秒，仅此一次），
之后直接走缓存。仅支持 macOS。

## 使用

自然语言、slash command、交互式菜单，怎么顺手怎么来：

| 对它说 | …或者运行 | 效果 |
| --- | --- | --- |
| "现在放的是什么歌？" | `/media:now` | 显示曲名 / 歌手 / 应用 + 进度条 |
| "暂停音乐" | `/media:pause` · `/media:toggle` | 暂停 / 恢复当前播放器 |
| "下一首" | `/media:next` · `/media:prev` | 切到下一首 / 上一首 |
| "跳到 1:30" | `/media:seek 1:30` | 跳转到指定位置 |
| "看看专辑封面" | `/media:artwork` | 保存封面并显示 |
| "来个音频频谱" | `/media:spectrum` | 正在播放内容的实时频谱柱（需手动开启） |
| "声音小一点" | `/media:volume 30` | 查看 / 设置系统音量（0–100） |
| "刚才放的是什么歌？" | `/media:history` | 最近播放的曲目列表（本地记录） |
| "用 AirPods 放" | `/media:output airpods` | 查看 / 切换音频输出设备 |
| "给我个遥控器" | `/media:menu` | 方向键操作的交互式控制器 |
| — | `/media:statusline` | 选择状态栏显示哪些内容以及如何排布 |
| — | `/media:config` | 开关各项显示功能（进度条、状态栏、频谱等） |
| — | `/media:doctor` | 诊断构建 / 权限 / 回退路径 |

还可以把正在播放的歌放进状态栏——见
[docs/statusline.zh-CN.md](docs/statusline.zh-CN.md)。显示哪些内容（曲目、
应用、进度条、时间、输出设备、频谱）、是并成一行还是分行，都在
`/media:statusline` 里选。超过 30 格的长标题会以跑马灯方式滚动
（`statusline.marquee`），状态栏组件自带 ANSI 样式——图标和进度条的颜色跟随
播放状态、曲名加粗、歌手斜体、频谱着色（纯色，或用 `spectrum.style` 开启按
位置循环的彩虹色）。想要纯文本的话，运行
`/media:config statusline.color off`（也支持 `NO_COLOR` 环境变量）。

## 工作原理

macOS 没有公开 API 可以读取其他应用的播放信息。私有的 `MediaRemote` 框架
可以做到，但从 macOS 15.4 起，它的守护进程只响应带 Apple 签名的进程。这个
插件用的是与
[ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter)
相同的技巧：让 Apple 的平台二进制 `/usr/bin/perl` 去加载一个小小的
Objective-C helper（`native/adapter.m`），从而通过 entitlement 检查。播放
控制和跳转走的也是同一条路。

如果 native helper 构建不了（比如没装 Command Line Tools），插件会回退到
免编译的 `osascript`/JXA 来读取信息，并用针对 Spotify 和 Apple Music 的
AppleScript 来实现控制。当前处于哪种模式，`/media:doctor` 会告诉你。

> **免责声明。** 这个插件依赖一个**私有的、没有文档的 Apple 框架**。它目前
> 在 macOS 26.x 上运行正常，每次 macOS 更新后也会自动重新验证（构建缓存以
> OS 构建号为键），但 Apple 随时可能改动或封掉这条路。真到那时，插件会降级
> 到回退路径继续工作，`/media:doctor` 会报告这一情况。不提供任何保证——见
> [LICENSE](LICENSE)。

## 音频频谱（需手动开启）

`/media:spectrum` 会把正在播放的声音画成实时的频谱柱：

```
63Hz ▂▄▆█▇▅▃▂ ▃▂▁▁ ▁ 16kHz   (peak: 1.2kHz)
```

加上 `--live <秒数>` 可以连续输出多帧；还可以用 `/media:statusline` 在
状态栏里放一个迷你频谱。

频谱柱按 `spectrum.color` 着色（默认 cyan）。改成
`/media:config spectrum.style rainbow` 后，颜色会按柱子的位置从前到后循环
（特意做成与音量无关）。颜色只在状态栏和直接在终端运行时可见；聊天回复里
是不带颜色的纯字符。

**声音是这样捕获的。** 用 Core Audio 的 *process tap*
（`AudioHardwareCreateProcessTap`，自 macOS 14.4 起是公开 API）读取系统
输出混音，再在本地用 Accelerate/vDSP 做 FFT 算出各个频段。**声音永远不会
离开你的电脑**——整个过程只产出一串频谱字符，不录制、不上传任何内容。

**默认关闭。** 一个控制音乐的插件跑来要音频录制权限，警惕一下是应该的，
所以频谱功能必须手动开启：

```
/media:config display.spectrum on
```

**权限。** process tap 需要你的终端应用拥有*系统音频录制*权限。macOS
**不会**为命令行工具自动弹出授权窗口，得手动去开：系统设置 > 隐私与安全性 >
屏幕与系统音频录制，在放着音乐的状态下启用你的终端（Terminal、iTerm 等）。
这个功能是 fail-closed 的：如果音乐在放、捕获到的却是静音，它会拒绝开启并
提示缺少哪个授权；之后权限被撤销的话，功能会自动关闭。权限状态可以用
`/media:doctor` 查看。

需要 macOS 14.4 及以上；更早的系统上这个功能不会出现，helper 也不会被编译。

## 播放历史与输出设备

`/media:history` 按从新到旧列出最近播放的曲目。记录**搭载**在本来就会发生
的读取上（状态栏刷新、`/media:now`、播放命令）——没有后台轮询，没有守护
进程，也没有额外的资源开销。日志只在插件数据目录里保留最近 500 首，绝不
离开你的电脑；`/media:config history.record off` 可以停止记录，
`/media:history clear` 可以清空。

`/media:output` 列出所有音频输出设备并在它们之间切换（"用 AirPods 放"）——
走的是公开的 CoreAudio API，不需要任何额外权限。状态栏也能显示当前设备：
在 `/media:statusline` 里选上 `output` 这一项。

## 环境要求

- **macOS**（在 macOS 26.x / Apple Silicon 上测试过；这套技巧面向 15.4 及
  以上）。其他操作系统在路线图里。
- **Xcode Command Line Tools**——只在首次构建 native helper 时用到。运行
  `xcode-select --install` 即可安装，不过你多半已经有了：克隆插件要用的
  `git` 和 `clang` 本来就装在同一套 Command Line Tools 里。就算没有，插件
  也能以回退模式运行。

不需要 Homebrew，不需要 Node，不需要 Python，也不需要 API 密钥。

## 验证安装

```
/media:doctor
```

安装正常的话，最后一行是 `verdict: PRIMARY OK`。如果显示 `DEGRADED`，报告
里会写明怎么修（通常是 `xcode-select --install`，然后
`/media:doctor --rebuild`）。

## 故障排查

| 症状 | 解决办法 |
| --- | --- |
| `DEGRADED — native helper unavailable` | `xcode-select --install`，然后 `/media:doctor --rebuild` |
| macOS 更新后出现 `PRIMARY READ LIKELY BLOCKED` | `/media:doctor --rebuild`；还不行就[提个 issue](https://github.com/Bangs00/claude-media-control/issues) |
| AppleScript 控制报 **error -1743** | 在系统设置 → 隐私与安全性 → 自动化里允许你的终端应用（仅回退模式需要） |
| 没在放歌，`now` 却显示一条曲目 | 是应用上报了过期状态；试试 `/media:next`，或重启那个播放器 |
| 频谱是静音的，或者 `display.spectrum on` 被拒绝 | 在系统设置 → 隐私与安全性里给终端应用授予**系统音频录制**权限（放着音乐授权），然后重试；权限状态看 `/media:doctor` |

构建日志在 `${CLAUDE_PLUGIN_DATA}/build.log`。

## 卸载

```
/plugin uninstall media@claude-media-control
/plugin marketplace remove claude-media-control
```

卸载后，**你的电脑会完全恢复到安装前的样子。** 插件创建的所有东西都只在
两个由 Claude 管理的目录里（`~/.claude/plugins/cache/...` 和
`~/.claude/plugins/data/...`），卸载时都会删掉——没有 LaunchAgent、没有登录
项、家目录里没有杂散文件、不改 `settings.json`、不装系统软件包。插件不往
别的任何地方写；临时的封面图放在 `$TMPDIR`，macOS 会自己清理。

有两样东西不是插件的文件，可能会留下来（都无害）：

- 如果你用过 AppleScript 回退模式，macOS 会在系统权限数据库里保留一条
  **自动化授权**记录（"终端 → Spotify/Music"）。想清掉的话，运行
  `tccutil reset AppleEvents`。
- 如果你配置过可选的状态栏 wrapper，删掉 `~/.claude/statusline-media.sh`，
  并把 `settings.json` 里原来的 `"statusLine"` 值改回去。

## 路线图

- ~~**音频频谱**（`/media:spectrum`）~~——已在 v0.2.0 发布（见上文）。
- **Linux** 支持，基于 `playerctl`/MPRIS——调度层已经按"每个 OS 一个后端"
  设计好了，欢迎贡献。
- **Windows** 支持，基于 SMTC（`GlobalSystemMediaTransportControls`）——
  欢迎贡献。

## 开发

```bash
claude --plugin-dir .          # 从检出目录加载插件
shellcheck scripts/*.sh        # lint
npx bats tests/media.bats      # 单元测试（native 已打桩）
claude plugin validate . --strict
```

CI 会跑上面的全部内容，另外还在 macOS runner 上做一次 strict 模式的
native 构建。

## 许可证

[MIT](LICENSE)。native adapter 移植了 ungive/mediaremote-adapter 的
BSD-3-Clause 技术，并参考了 ungive/media-control 的 CLI/JSON 约定——见
[native/NOTICE](native/NOTICE)。
