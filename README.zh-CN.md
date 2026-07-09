# claude-media-control

[![CI](https://github.com/Bangs00/claude-media-control/actions/workflows/ci.yml/badge.svg)](https://github.com/Bangs00/claude-media-control/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![macOS](https://img.shields.io/badge/platform-macOS-black)
![Claude Code plugin](https://img.shields.io/badge/Claude%20Code-plugin-d97757)
![Zero dependencies](https://img.shields.io/badge/dependencies-zero-brightgreen)

[English](README.md) | [한국어](README.ko.md) | [日本語](README.ja.md) | **简体中文**

直接在 Claude Code 中查看并控制 **Mac 上正在播放的一切** — Spotify、
Apple Music、浏览器、VLC。问一句"现在放的是什么歌？"，说一声"暂停音乐"，
或者打开一个交互式遥控器。无需 OAuth、无需 API 密钥、无需针对单个应用的
集成，**也无需用 Homebrew 安装任何东西**。

![claude-media-control 演示](docs/demo.zh-CN.gif)

## 为什么选它

现有的 Claude/Spotify/Apple Music 集成各自绑定一个应用，并且需要
OAuth/AppleScript 配置。本插件与 **macOS 系统级 now-playing 服务**通信，
因此无论是哪个应用，它都能识别并控制*当前活跃的*播放器 — 并且**零第三方
依赖**。唯一的要求是 Xcode Command Line Tools，如果你的环境能 `git clone`，
那么它们已经装好了（见[环境要求](#环境要求)）。

## 安装

在 Claude Code 里两行命令即可 — 没有 Homebrew 步骤:

```
/plugin marketplace add Bangs00/claude-media-control
/plugin install media@claude-media-control
```

第一条 media 命令会构建一个小巧的 native helper（约 2 秒，仅首次），之后
使用缓存。仅支持 macOS。

## 使用

自然语言、slash command、交互式菜单，三种方式都可以:

| 这样说 | …或运行 | 效果 |
| --- | --- | --- |
| "现在放的是什么歌？" | `/media:now` | 当前标题 / 艺人 / 应用 + 进度条 |
| "暂停音乐" / "pause the music" | `/media:pause` · `/media:toggle` | 暂停 / 恢复当前播放器 |
| "下一首" | `/media:next` · `/media:prev` | 下一首 / 上一首 |
| "跳到 1:30" | `/media:seek 1:30` | 跳转到绝对位置 |
| "看看专辑封面" | `/media:artwork` | 保存并显示封面 |
| "来个音频频谱" | `/media:spectrum` | 正在播放内容的实时频率条（需手动开启） |
| "小点声" | `/media:volume 30` | 读取 / 设置系统输出音量（0–100） |
| "给我个遥控器" | `/media:menu` | 交互式控制器（方向键菜单） |
| — | `/media:statusline` | 选择 now-playing 状态栏的显示项 + 布局 |
| — | `/media:config` | 切换显示功能（进度条、状态栏、频谱） |
| — | `/media:doctor` | 诊断构建 / 权限 / 回退路径 |

可选: 把 now-playing 放进你的状态栏 — 见
[docs/statusline.zh-CN.md](docs/statusline.zh-CN.md)。用 `/media:statusline`
选择显示哪些项（track、progress bar、time、spectrum），以及是否将各组内容
分行堆叠。状态栏区块自带 ANSI 样式 — 随播放状态变色的图标和进度条、加粗的
标题、斜体的艺人、着色的频谱（纯色，或通过 `spectrum.style` 设置按位置循环
的彩虹色）— 运行 `/media:config statusline.color off`（或设置 `NO_COLOR`）
可恢复纯文本。

## 工作原理

macOS 没有公开 API 可以读取其他应用的 now-playing 信息；私有的
`MediaRemote` 框架可以，但自 macOS 15.4 起，它的守护进程只响应由 Apple
签名的进程。本插件使用与
[ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter)
相同的技术: 一个小型 Objective-C helper（`native/adapter.m`）由
`/usr/bin/perl` — 一个 Apple 平台二进制 — 加载，从而通过 entitlement 检查。
播放控制和跳转走同一条路径。

如果 native helper 无法构建（没有 Command Line Tools），插件会回退到基于
`osascript`/JXA 的免编译读取，并通过针对 Spotify 和 Apple Music 的
AppleScript 实现控制。`/media:doctor` 会告诉你当前处于哪种模式。

> **免责声明。** 本插件依赖一个**私有的、无文档的 Apple 框架**。
> 它目前在 macOS 26.x 上工作正常，并且每次 macOS 更新后都会自动重新验证
> （构建缓存以 OS 构建号为键），但 Apple 随时可能更改或封锁它。届时插件会
> 降级到回退路径，`/media:doctor` 会报告这一情况。不提供任何保证 — 见
> [LICENSE](LICENSE)。

## 音频频谱（需手动开启）

`/media:spectrum` 以实时频率条的形式渲染正在播放的内容:

```
63Hz ▂▄▆█▇▅▃▂ ▃▂▁▁ ▁ 16kHz   (peak: 1.2kHz)
```

`--live <seconds>` 可以连续输出多帧，还可以用 `/media:statusline` 在状态栏
中加一个迷你频谱。

频率条按 `spectrum.color` 着色（默认 cyan）— 或运行
`/media:config spectrum.style rainbow` 启用按条位置从前到后循环的彩虹色
（有意不随音量变化）。着色在状态栏和直接在终端运行时可见；聊天回复保持
纯字符。

**如何捕获音频。** 一个 Core Audio *process tap*
（`AudioHardwareCreateProcessTap`，自 macOS 14.4 起为公开 API）读取系统
输出混音；本地的 Accelerate/vDSP FFT 将其转换为频段。**音频永远不会离开
你的机器** — 只生成频率条字符串，不录制、不传输任何内容。

**默认关闭。** 一个音乐控制插件要求音频录制权限，理应受到审视，因此频谱
功能需要手动开启:

```
/media:config display.spectrum on
```

**权限。** process tap 需要你的终端应用拥有*系统音频录制*权限。macOS
**不会**为命令行工具自动弹出授权提示，请手动授予: 系统设置 > 隐私与安全性 >
屏幕与系统音频录制，在有音频播放时启用你的终端（Terminal、iTerm 等）。
开启过程是 fail-closed 的 — 如果音频在播放而捕获结果是静音，它会拒绝开启并
指出缺失的授权；如果之后权限被撤销，该功能会自行禁用。`/media:doctor` 会
报告权限状态。

需要 macOS 14.4+；在更早的系统上该功能保持隐藏，helper 也不会被编译。

## 环境要求

- **macOS**（在 macOS 26.x / Apple Silicon 上测试；该技术面向 15.4+）。
  其他操作系统在路线图中。
- **Xcode Command Line Tools** — 用于一次性的 native 构建。运行
  `xcode-select --install` 安装。你几乎肯定已经装好了: 克隆插件需要 `git`，
  而它与 `clang` 同属一套 Command Line Tools。没有它们插件也能以回退模式
  运行。

不需要 Homebrew、Node、Python，也不需要 API 密钥。

## 验证安装

```
/media:doctor
```

健康的安装以 `verdict: PRIMARY OK` 结束。如果显示 `DEGRADED`，报告会给出
修复方法（通常是 `xcode-select --install`，然后 `/media:doctor --rebuild`）。

## 故障排查

| 症状 | 解决办法 |
| --- | --- |
| `DEGRADED — native helper unavailable` | `xcode-select --install`，然后 `/media:doctor --rebuild` |
| macOS 更新后出现 `PRIMARY READ LIKELY BLOCKED` | `/media:doctor --rebuild`；若仍未解决，请[提交 issue](https://github.com/Bangs00/claude-media-control/issues) |
| AppleScript 控制报 **error -1743** | 在系统设置 → 隐私与安全性 → 自动化中批准你的终端应用（仅回退模式） |
| 没有在播放，但 `now` 显示一条曲目 | 应用上报了过期状态；试试 `/media:next` 或重启播放器 |
| 频谱静音，或 `display.spectrum on` 被拒绝 | 在系统设置 → 隐私与安全性中授予终端应用**系统音频录制**权限（在有音频播放时），然后重试；`/media:doctor` 会显示权限状态 |

构建日志位于 `${CLAUDE_PLUGIN_DATA}/build.log`。

## 卸载

```
/plugin uninstall media@claude-media-control
/plugin marketplace remove claude-media-control
```

这会**将你的机器完全恢复到安装前的状态。** 插件创建的一切都位于两个由
Claude 管理的目录（`~/.claude/plugins/cache/...` 和
`~/.claude/plugins/data/...`），卸载时都会被删除 — 没有 LaunchAgent、没有
登录项、没有家目录文件、不改 `settings.json`、没有系统软件包。插件不会写入
其他任何位置；临时封面图放在 `$TMPDIR`，由 macOS 自行清理。

有两样东西不属于插件文件，可能会保留（都无害）:

- 如果你用过 AppleScript 回退，macOS 会在系统权限数据库中保留**自动化授权**
  （"终端 → Spotify/Music"）。想清除的话运行 `tccutil reset AppleEvents`。
- 如果你添加过可选的状态栏 wrapper，请删除 `~/.claude/statusline-media.sh`
  并恢复 `settings.json` 中原来的 `"statusLine"` 值。

## 路线图

- ~~**音频频谱**（`/media:spectrum`）~~ — 已在 v0.2.0 发布（见上文）。
- **Linux** 后端，基于 `playerctl`/MPRIS — 调度器已按每个 OS 一个后端的
  结构设计；欢迎贡献。
- **Windows** 后端，基于 SMTC（`GlobalSystemMediaTransportControls`）—
  欢迎贡献。

## 开发

```bash
claude --plugin-dir .          # 从检出目录加载插件
shellcheck scripts/*.sh        # lint
npx bats tests/media.bats      # 单元测试（native 已打桩）
claude plugin validate . --strict
```

CI 会运行以上全部内容，外加在 macOS runner 上的 strict native 构建。

## 许可证

[MIT](LICENSE)。native adapter 移植了 ungive/mediaremote-adapter 的
BSD-3-Clause 技术，并参考了 ungive/media-control 的 CLI/JSON 约定 — 见
[native/NOTICE](native/NOTICE)。
