# 把正在播放的歌放进状态栏

[English](statusline.md) | [한국어](statusline.ko.md) | [日本語](statusline.ja.md) | **简体中文**

在 Claude Code 的状态栏里加一行，显示当前播放的曲目：

```
[你原来的状态栏，原样保留]
▶︎ Karma Police — Radiohead (Spotify)  ━━━━━━━━━━━━────────  2:13/4:24
```

组件从一个 1 秒 TTL 的缓存应答，耗时远低于 50ms——绝不会拖慢你的状态栏。
真正的播放信息读取每秒最多一次，时间和进度条每秒走一格也正是靠这个节拍。

## 开启

```
/media:config display.statusline on
```

整个设置就这一步——不用重启，没有手动步骤。（在 `/media:statusline` 里
保存布局也会以同样的方式开启。）开启前会先验证播放信息确实读得到（被拒绝
就运行 `/media:doctor`），然后自动把组件接进来：

1. 把 `~/.claude/settings.json` 里当前的 `"statusLine"` 值备份到
   `~/.claude/statusline-media.backup.json`（原来没有就记 `null`）。
2. 在 `~/.claude/statusline-media.sh` 生成一个 wrapper：先原样运行你之前
   的状态栏命令，再把正在播放这一行追加在后面。
3. 让 `settings.json` 指向这个 wrapper。原条目的其他键（如 `padding`）
   全部保留；如果你没设置过，会补上 `refreshInterval: 1`——正是这个每秒
   一次的重跑，让你不操作时时间和进度条也在走。（想少重绘几次就调大或
   删掉它；每次重绘也会连带重跑你原来的状态栏命令。）

## 点击操控

在支持超链接的终端里，这个组件可以 **⌘+点击**：

| 目标 | ⌘+点击的效果 |
| --- | --- |
| `▶︎` / `⏸` 图标 | 切换播放/暂停 |
| 曲名 — 歌手、`(应用)` | 跳到正在播放的媒体：正在播放的浏览器标签页（Safari、Chrome、Edge、Brave、Vivaldi、Opera）或 Music 的当前曲目——其他应用只是调到最前 |
| 进度条 | seek——每个格子各自跳到对应位置（默认 20 格时是 2.5%、7.5%、… 97.5%；条越长跳得越细） |

- **支持的终端**：iTerm2、Ghostty、WezTerm、Kitty、VS Code、Alacritty
  0.11+（tmux 3.4+ 会透传超链接）。不认识超链接的终端只会显示普通组件。
- 点击的结果在下一次刷新（1 秒内）就能看到：图标翻转，进度条跳走。
- 开关：`/media:config statusline.links off` 恢复成不带链接的普通组件。
  再打开会重建处理器应用，构建失败则拒绝开启（exit 3）——没人应答的
  链接还不如没有。
- 第一次跳标签页时会请求一次自动化授权（`ClaudeMediaClick.app`）——
  拒绝也没关系，之后会安静地只做到把应用调到最前。

<details>
<summary>点击的原理（以及为什么安全）</summary>

可点击的部分是指向本地 `claude-media://` URL scheme 的 OSC 8 超链接。
开启状态栏时会顺带生成一个小处理器应用（`ClaudeMediaClick.app`——用
macOS 自带的 `osacompile` 生成到插件数据目录，零第三方代码），并注册进
LaunchServices。点击后运行 `media.sh open-url`，它接受的操作恰好只有
三个——toggle、activate、按百分比 seek——其余一律拒绝。URL scheme 天生
是系统级入口，任何应用都能打开它，所以把表面收得这么窄本身就是重点：
播放/暂停、把播放器调到最前、跳转——最坏也就是烦人的程度，和键盘上的
媒体键同一级别。

对浏览器里的播放，激活时会把网页内容辅助进程解析回所属应用（例如
`com.openai.atlas.web` → ChatGPT Atlas），应用支持脚本控制的话还会落到
媒体本身：选中标题匹配曲目的窗口+标签页，或让 Music 定位到当前曲目。
没有脚本接口的应用（如 ChatGPT Atlas、Spotify）到调到最前为止。卸载
插件（或运行 `media.sh statusline uninstall`）时，处理器应用会一并注销
并删除。`/media:doctor` 会报告它的状态（`Click links`）。

</details>

## 排布组件的内容

`/media:statusline` 是决定组件外观的中枢——三个标签页：**Items**（开关）、
**Layout**（预设或数字模式）、**Style**（见[样式图鉴](styles.zh-CN.md)）。
数字模式用这份图例：

| # | 条目 | 效果 |
| --- | --- | --- |
| 1 | `track` | `▶︎ Karma Police — Radiohead` |
| 2 | `app` | `(Spotify)` |
| 3 | `volume` | `🔉 ▄ 45%`——静音时 `🔇` |
| 4 | `progressbar` | `━━━━━━━━━━━━────────` |
| 5 | `time` | `2:13/4:24` |
| 6 | `output` | `🎧 AirPods Pro`——图标随设备类型 |

数字顺序就是显示顺序，`/` 起新行，没写的数字对应的条目就不显示。默认
组合是 `track app progressbar time`；也可以直接设置列表：
`/media:config statusline.fields "time,progressbar,track,app"`。

Standard——全部放一行（`123456`）：

```
▶︎ Karma Police — Radiohead (Spotify)  🔉 ▄ 45%  ━━━━━━━━━━━━────────  2:13/4:24  🎧 AirPods Pro
```

Stacked——两行（`123/456`）：

```
▶︎ Karma Police — Radiohead (Spotify)  🔉 ▄ 45%
━━━━━━━━━━━━────────  2:13/4:24  🎧 AirPods Pro
```

输出设备放到曲目那一行，不要音量（`126/45`）：

```
▶︎ Karma Police — Radiohead (Spotify)  🎧 AirPods Pro
━━━━━━━━━━━━────────  2:13/4:24
```

布局的规则：

- **列表里有 `/`**（显式布局）：每行只显示你放上去的条目，按你给的顺序。
  没有内容可显示的行整行消失——不会出现空行。
- **没有 `/`**（分组布局）：拼成一行，或开 `statusline.multiline on` 让
  每组占一行。分组规则：`app` 贴在 track 上，相邻的 `progressbar`+`time`
  结成一对，`output`/`volume` 并入相邻的 track 组（两者相邻时自成一对）。
- `output` 和 `volume` 需要 native helper；它们搭组件本来就要做的那次
  读取的便车，不产生额外开销。

## 样式

组件出厂自带样式：随播放状态切换的 green/yellow 强调色、**加粗**的曲名
和已播时间、*斜体*的歌手、暗淡处理的其余部分——只用标准 16 色 SGR，
实际色调由你终端的调色板决定。

每个部分都能单独定制——颜色（色名或 `#ff8800` 这样的十六进制色号）、
粗体/斜体、22 套进度条字符、进度条长度
（1–60 格，默认 20）、音量条形状、图标，还有 `off` 隐藏任意部分。
**完整目录、示例和现成搭配：
[docs/styles.zh-CN.md](styles.zh-CN.md)**

```
/media:config statusline.color off     # 纯文本（也支持 NO_COLOR）
/media:config statusline.marquee off   # 不滚动长曲名
```

超过 30 格（终端单元格）的曲名会在固定宽度的窗口里以跑马灯方式滚动，
每秒一个字符（汉字、假名、谚文按两格计，窗口宽度保持稳定）。

## 开关速查

| 键（`/media:config …`） | 默认 | 作用 |
| --- | --- | --- |
| `display.statusline` | `off` | 显示组件（开启时自动接线） |
| `statusline.fields` | `track,app,progressbar,time` | 条目、顺序、`/` 分行 |
| `statusline.multiline` | `off` | 分组布局下每组一行 |
| `statusline.color` | `on` | ANSI 样式（`NO_COLOR` 优先） |
| `statusline.marquee` | `on` | 滚动超过 30 格的曲名 |
| `statusline.links` | `on` | ⌘+点击操作 |
| `statusline reset` | — | 恢复出厂外观（布局、分行、颜色、marquee、样式） |

## 手动接线（自定义状态栏）

想自己掌管接线——比如把组件嵌进你自己的状态栏脚本*里面*，而不是追加
一行？先把命令配置**好**，再开启：自动接线认得已经在运行组件的
`statusLine` 命令（包含 `statusline-media.sh` 或 `media.sh … statusline`
的都算），会完全不碰它，开启只是拨一下显示开关。

一个可以直接起步的通用 wrapper——存成 `~/.claude/statusline-media.sh`
并 `chmod +x`：

```bash
#!/bin/bash
# statusline-media.sh — 原有状态栏（原样）+ 正在播放一行。
input=$(cat)

# ── 1. 把你原来的 statusLine 命令原样粘贴到引号之间。
#       从 settings.json 里 "statusLine" 下的 "command" 值复制即可。
#       原来没有状态栏就让 EXISTING 留空。
EXISTING=''
if [ -n "$EXISTING" ]; then
  printf '%s' "$input" | bash -c "$EXISTING"
fi

# ── 2. 正在播放（关闭 / 没在播放 / 插件不存在时不输出任何内容）。
#       运行时解析已安装的最新插件版本，插件升级后 wrapper 照常工作。
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

然后自己把 `~/.claude/settings.json` 指向它：

```json
{
  "statusLine": {
    "type": "command",
    "command": "\"$HOME/.claude/statusline-media.sh\"",
    "refreshInterval": 1
  }
}
```

从检出的仓库开发（`claude --plugin-dir`）？把 `MEDIA_DIR` 那段换成你的
仓库路径：
`np="$(/path/to/claude-media-control/scripts/media.sh statusline 2>/dev/null)"`

## 设计保证（为什么可以放心）

1. 你原来的状态栏**不会被替换**——wrapper 先原样运行它，输出逐字节
   透传；正在播放的信息永远只作为独立的一行追加。
2. 关闭（默认）时什么都不输出——连空行都没有。Claude Code 会收起不存在
   的行，状态栏看起来和从前一模一样。
3. `settings.json` 里动的键只有一个——`statusLine`——而且一定先备份旧值。
   写入是原子的、会跟随符号链接（dotfiles 配置无恙），其他键分毫不动。
4. **卸载插件后一切自动还原。** Claude Code 没有卸载钩子，所以 wrapper
   会自愈：发现插件没了，就把备份的 `statusLine` 恢复回 `settings.json`，
   删掉自己和备份文件，顺带移除点击处理器应用——卸载后一秒之内完成。
5. 插件只是被**停用**时，wrapper 什么也不追加、静静等着——你之前的状态栏
   照常运行。
6. **手动**接线的状态栏会被识别出来，安装和卸载都绝不去碰。

## 接线命令

```
media.sh statusline status      # managed | manual | none（/media:doctor 里也有）
media.sh statusline uninstall   # 不卸载插件、只解开接线：
                                # 恢复备份，删除 wrapper + 备份，
                                # 把 display.statusline 关掉
```

备注：

- **自动接线（managed）**：wrapper 是生成的文件——别手改；插件升级时和
  重跑 `media.sh statusline install` 时都会重新生成。
- **手动接线（manual）**：文件是你的，插件永远不碰。之后改了状态栏配置，
  记得同步更新 `EXISTING` 那行。只卸载插件的话组件会自己安静下来，但
  wrapper 的删除和 `"statusLine"` 的恢复要你自己来。
- `/media:config display.statusline off` 立即生效——关闭的瞬间缓存的行
  就被删掉；接线保留，再开也是立即的。
