# claude-media-control

[![CI](https://github.com/Bangs00/claude-media-control/actions/workflows/ci.yml/badge.svg)](https://github.com/Bangs00/claude-media-control/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![macOS](https://img.shields.io/badge/platform-macOS-black)
![Claude Code plugin](https://img.shields.io/badge/Claude%20Code-plugin-d97757)
![Zero dependencies](https://img.shields.io/badge/dependencies-zero-brightgreen)

[English](README.md) | [한국어](README.ko.md) | [日本語](README.ja.md) | **简体中文**

**正在播放的歌，实时挂在 Claude Code 的状态栏上**——每秒都在走，可以
⌘+点击操控，连进度条用什么字符都随你定：

```
▶︎ Karma Police — Radiohead (Spotify)  🔉 ▄ 45%
━━━━━━━━━━━━────────  2:13/4:24  🎧 AirPods Pro
```

Mac 上在放什么都行——Spotify、Apple Music、浏览器标签页、VLC——在聊天里
也能直接控制："现在放的是什么歌？"、"暂停"、"下一首"、"用 AirPods 放"。
它直接对接 **macOS 系统级的 now-playing 服务**，所以不绑定任何应用，
不需要 OAuth、不需要 API 密钥，也不需要用 Homebrew 装任何东西。

![claude-media-control 演示](docs/demo.zh-CN.gif)

## 快速开始

在 Claude Code 里：

```
/plugin marketplace add Bangs00/claude-media-control
/plugin install media@claude-media-control
/media:config display.statusline on
```

最后一行就是状态栏——自动接好线，下一次刷新就能看到。仅支持 macOS；
第一次运行 media 命令会构建一个很小的 native helper（约 2 秒，仅此
一次）。用 `/media:doctor` 验证安装（健康 = `verdict: PRIMARY OK`）。

## 状态栏

下面这些全是自动的——完整指南见
[docs/statusline.zh-CN.md](docs/statusline.zh-CN.md)：

- **安全接线。** 开启后，组件作为独立的一行追加在你原有状态栏后面——
  原有部分逐字节原样运行。之前的 `statusLine` 值会先备份，**卸载插件时
  自动恢复**。不用重启，没有手动步骤。
- **⌘+点击操控**（iTerm2、Ghostty、WezTerm、Kitty、VS Code 等）：▶︎/⏸
  图标切换播放/暂停，曲名跳到正在播放的浏览器标签页或 Music 曲目，
  进度条的每个格子都能点击跳转。不支持的终端只会显示普通组件。
- **数字模式排布**——在 `/media:statusline` 里：数字就是条目——1 曲目 ·
  2 应用 · 3 音量 · 4 进度条 · 5 时间 · 6 输出设备——`/` 起新行，
  所以 `123/456` 就是曲目/应用/音量在上，进度条/时间/输出在下。
- **逐项定制样式**：播放/暂停强调色，每个部分的粗体/斜体/颜色（色名或
  `#ff8800` 这样的十六进制色号），31 套
  进度条字符（从默认的 `line` `━━──` 到 `smooth` 部分块、`knob` 滑块头，
  铺满整条的 `wave`/`pulse`/`eq`/`notes` 波形及其点阵孪生版，音频可视化
  `spectrum`/`mirror`/`cava`/`ripple`，以及 `heartbeat` 心电图 `━━┻┳━━`），
  进度条长度（1–60 格），
  音量条形状、图标——还能用 `off` 隐藏任意部分。**全部效果带示例，见
  [样式图鉴](docs/styles.zh-CN.md)；整套外观可直接粘贴
  [现成搭配](docs/recipes.zh-CN.md)。**

## 在聊天里控制

自然语言、slash command、交互式菜单，怎么顺手怎么来：

| 对它说 | …或者运行 | 效果 |
| --- | --- | --- |
| "现在放的是什么歌？" | `/media:now` | 曲名 / 歌手 / 应用 + 进度条 |
| "暂停音乐" | `/media:pause` · `/media:toggle` | 暂停 / 恢复 |
| "下一首" | `/media:next` · `/media:prev` | 下一首 / 上一首 |
| "跳到 1:30" | `/media:seek 1:30` | 跳转到指定位置 |
| "看看专辑封面" | `/media:artwork` | 保存封面并显示 |
| "声音小一点" | `/media:volume 30` | 系统音量（0–100） |
| "刚才放的是什么歌？" | `/media:history` | 最近播放的曲目 |
| "用 AirPods 放" | `/media:output airpods` | 查看 / 切换输出设备 |
| "给我个遥控器" | `/media:menu` | 方向键交互控制器 |
| "把曲名改成青色" | `/media:statusline` | 状态栏布局 + 样式 |
| "关掉播放历史" | `/media:config` | 快捷开关 + 状态栏重置 |
| — | `/media:doctor` | 诊断构建 / 权限 / 回退路径 |

播放历史是**搭便车**记录的——搭在反正要发生的读取上（状态栏刷新、
各种命令），没有轮询、没有守护进程。日志只在本地保留最近 500 首，
绝不离开你的机器（`/media:config history.record off` 停止记录，
`/media:history clear` 清空）。输出设备的列出和切换走公开的 CoreAudio
API——不需要额外权限。

## 工作原理

macOS 没有读取其他应用播放信息的公开 API；私有的 `MediaRemote` 框架从
15.4 起只应答 Apple 签名的进程。本插件采用与
[ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter)
相同的手法：让 Apple 平台二进制 `/usr/bin/perl` 加载一个小的 Objective-C
辅助库（`native/adapter.m`），从而通过 entitlement 检查。没有 Command
Line Tools？读取会回退到免编译的 `osascript`/JXA，控制回退到按应用的
AppleScript（Spotify / Apple Music）。当前处于哪种模式，`/media:doctor`
会告诉你。

> **声明。** 本插件依赖一个**未文档化的 Apple 私有框架**。目前在 macOS
> 26.x 上工作正常，并且每次 macOS 更新后都会自动重新验证（构建缓存与
> OS 构建号绑定），但 Apple 随时可能更改或封锁它——届时插件会降级到
> 回退路径，`/media:doctor` 会报告。不提供任何保证——见
> [LICENSE](LICENSE)。

## 环境要求

- **macOS**（在 26.x / Apple Silicon 上测试；该手法面向 15.4+）。
- **Xcode Command Line Tools**——只为那一次构建。能跑 `git clone` 的机器
  就已经有了（没有就 `xcode-select --install`；不装也能以回退模式运行）。

不需要 Homebrew、Node、Python，也不需要 API 密钥。

## 疑难排查

| 症状 | 处理 |
| --- | --- |
| `DEGRADED — native helper unavailable` | `xcode-select --install`，然后 `/media:doctor --rebuild` |
| macOS 更新后出现 `PRIMARY READ LIKELY BLOCKED` | `/media:doctor --rebuild`；仍然如此请[提 issue](https://github.com/Bangs00/claude-media-control/issues) |
| AppleScript 控制报 **error -1743** | 在系统设置 → 隐私与安全性 → 自动化里允许你的终端（仅回退模式需要） |
| 没在播放却在 `now` 里看到曲目 | 应用上报了过期状态——试试 `/media:next` 或重启播放器 |

构建日志：`${CLAUDE_PLUGIN_DATA}/build.log`

## 卸载

```
/plugin uninstall media@claude-media-control
/plugin marketplace remove claude-media-control
```

卸载后**机器完全回到安装前的状态。** 一切都只存在于 Claude 管理的两个
目录（`~/.claude/plugins/cache/…` 和 `…/data/…`）里——没有 LaunchAgent，
没有登录项，没有系统包。状态栏的接线会自我还原：卸载后的第一次刷新，
wrapper 就把之前的 `statusLine` 恢复回去，删掉自己和备份，顺带移除点击
处理器应用——一秒之内，状态栏原样归位（[详情](docs/statusline.zh-CN.md)）。

可能留下两样无害的东西：用过 AppleScript 回退的话，macOS 会保留一条
**自动化授权**记录（`tccutil reset AppleEvents` 可清除）；如果你是
**手动**接线的状态栏，那些文件归你所有，请自行删除。

## 路线图

- **Linux** 走 `playerctl`/MPRIS，**Windows** 走 SMTC——调度器已经按
  多操作系统后端的结构组织好了，欢迎贡献。

## 开发

```bash
claude --plugin-dir .          # 从检出目录加载插件
shellcheck scripts/*.sh        # 代码检查
npx bats tests/media.bats      # 单元测试（native 已打桩）
claude plugin validate . --strict
```

CI 会跑上面全部，外加在 macOS runner 上的 strict 模式 native 构建。

## 许可证

[MIT](LICENSE)。native adapter 移植了 ungive/mediaremote-adapter 的
BSD-3-Clause 手法，并参考了 ungive/media-control 的 CLI/JSON 约定——见
[native/NOTICE](native/NOTICE)。
