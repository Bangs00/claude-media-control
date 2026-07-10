# 把正在播放的歌放进状态栏

[English](statusline.md) | [한국어](statusline.ko.md) | [日本語](statusline.ja.md) | **简体中文**

在 Claude Code 的状态栏里加一行，显示当前播放的曲目:

```
[你原来的状态栏，原样保留]
▶︎ Karma Police — Radiohead  ━━━━━━────  2:13/4:24
```

这一行由 `media.sh statusline` 生成。它从一个小的 TTL 缓存（默认 1 秒）
应答，耗时远低于 50ms——绝不会拖慢你的状态栏。真正的播放信息读取在每个
TTL 窗口内最多执行一次，所以状态栏每次重绘时，经过时间和进度条大约每秒
往前走一格。

## 开启

在 Claude Code 里:

```
/media:config display.statusline on
```

设置就这一步。开启时会先验证播放信息确实读得到（如果被拒绝，跑一下
`/media:doctor`），然后自行把组件接进 Claude Code:

1. 把 `~/.claude/settings.json` 里当前的 `"statusLine"` 值备份到
   `~/.claude/statusline-media.backup.json`（原来没有就记为 `null`）。
2. 在 `~/.claude/statusline-media.sh` 生成一个 wrapper 脚本: 它先执行
   你之前的状态栏命令，再把播放信息一行追加在后面。
3. 让 `settings.json` 的 `statusLine` 指向 wrapper。你条目里的其他键
   （比如 `padding`）全都保留；只要你没自己设置过，还会补上
   `refreshInterval: 1`——状态栏平时只在会话有动静时才刷新，正是这个
   每秒一次的重跑，让经过时间和进度条在你不操作时也一直在走（想少刷新
   几次，就在 `settings.json` 里调大数值或去掉它；每次重绘也会连带重跑
   你原来的状态栏命令）。

组件会在下一次状态栏刷新时出现——不用重启，也没有手动步骤。在
`/media:statusline` 里排布组件，同样会以这种方式开启（并接好线）。

## 设计上的保证（为什么可以放心加）

1. 你原来的状态栏命令**不会被替换**——wrapper 会先原样执行它，输出
   **逐字节原样**透传。播放信息永远只会**作为单独的一行追加**在后面。
2. `display.statusline` 关闭时（默认就是关的），组件什么都不输出——
   连空行都没有。Claude Code 会自动收起不存在的行，所以状态栏看起来和
   原来一模一样。（`off` 会立即隐藏组件并保留接线，所以重新开启也是
   立即的。）
3. `settings.json` 里动到的键始终只有一个——`statusLine`——而且一定
   先把它之前的值存进 `statusline-media.backup.json` 再动手。写入是
   原子的，会跟随符号链接（dotfile 式的配置也安然无恙），其他设置键
   一概不碰。
4. **卸载插件后，一切都会自己还原。** Claude Code 没有可供插件使用的
   uninstall 钩子，所以 wrapper 是自愈式的: 每次刷新它都会检查已安装
   插件的注册表，一旦发现插件不在了，就把备份的 `statusLine` 恢复回
   `settings.json`，并删掉自己和备份文件。什么都不留——卸载后一秒之内，
   你的状态栏就恢复成原来的模样。
5. 插件只是被**禁用**时，wrapper 什么都不追加，只是等着——你之前的
   状态栏照常运行，接线留着等你重新开启。
6. 你**自己动手**接线的状态栏（按下面的做法配置的，或任何已经在运行
   组件的命令）会被识别出来，无论安装还是卸载都绝不去碰。

不卸载插件、只拆掉接线——恢复备份、删除 wrapper 和备份文件，并把
`display.statusline` 关掉:

```
media.sh statusline uninstall     # 或者直接对 Claude 说: "把状态栏接线拆掉"
```

`media.sh statusline status` 会报告当前的接线状态（`managed`、`manual`
或 `none`），`/media:doctor` 的报告里也包含这一项。

## 排布显示的内容

运行 `/media:statusline` —— 组件外观的统一中枢。它会打开三个标签页:
**Items**（音量、进度条、时间、输出设备的开关）、**Layout**（Standard /
Stacked 或数字模式）、**Style**（逐项样式，见下一节）。数字模式按下面的
图例来组:

| # | 条目 | 显示效果 |
| --- | --- | --- |
| 1 | `track` | `▶︎ Karma Police — Radiohead` |
| 2 | `app` | `(Spotify)` |
| 3 | `volume` | `🔉 ▄ 45%` — 图标 + 随音量升降的柱条 + 百分比，静音时显示 `🔇` |
| 4 | `progressbar` | `━━━━━━────` |
| 5 | `time` | `2:13/4:24` |
| 6 | `output` | `🎧 AirPods Pro` — 图标跟着设备类型走: `🎧` 蓝牙/耳机孔 · `📺` HDMI/DisplayPort · `📶` AirPlay · `🔊` 扬声器 |

数字顺序就是显示顺序。`/` 表示换行。没写的数字对应的条目就不显示。比如
`123/456`: 第一行是 track、app 和音量，其余放第二行。默认组合是
`track app progressbar time`；快捷开关和状态栏整体重置在 `/media:config`
里。

布局的行为:

- **顺序** — 条目严格按保存的顺序渲染。直接说"时间放最前面"，或者手动
  指定: `/media:config statusline.fields "time,progressbar,track,app"`。
- **显式分行** — 在条目列表里加 `/`，就在那里换行。每一行只显示放在这一行
  的条目，按给定顺序渲染。没内容可显示的行会整行消失（比如没有原生 helper
  时的 `output`）。
- **分组布局**（列表不含 `/` 时）— 并成一行，或者用
  `statusline.multiline on` 让每组各占一行。分组规则: `app` 贴在 track
  那一组里。`progressbar` 和 `time` 相邻时共用一组。`output` 和 `volume`
  会并入相邻的 track 组，两者相邻时自己也合成一组。

Standard — 所有内容放一行（模式 `123456`）:

```
▶︎ Karma Police — Radiohead (Spotify)  🔉 ▄ 45%  ━━━━━━────  2:13/4:24  🎧 AirPods Pro
```

Stacked — 显式两行布局（模式 `123/456`，即
`statusline.fields "track,app,volume,/,progressbar,time,output"`）:

```
▶︎ Karma Police — Radiohead (Spotify)  🔉 ▄ 45%
━━━━━━────  2:13/4:24  🎧 AirPods Pro
```

输出设备跟在 track 行、不带音量（模式 `126/45`）:

```
▶︎ Karma Police — Radiohead (Spotify)  🎧 AirPods Pro
━━━━━━────  2:13/4:24
```

时间在前，单行（模式 `5412`，即
`statusline.fields "time,progressbar,track,app"`）:

```
2:13/4:24  ━━━━━━────  ▶︎ Karma Police — Radiohead (Spotify)
```

`output` 和 `volume` 这两项需要原生 helper（它们搭载在组件本来就要做的
那次读取上，不产生额外开销）。切换设备用 `/media:output`，调音量用
`/media:volume`，组件会在下一次刷新时更新。

### 长标题: 跑马灯滚动

超过 30 个终端单元格宽的标题，会在固定 30 格的窗口里以每秒一个字符的速度
滚动。（窗口每次重绘前进一格——见下文的 1 秒刷新。）

```
▶︎ ing Willow (10 Minute Version)  — Taylor Swift (Music)
```

汉字、假名、谚文都按两格计算，所以中日韩标题的窗口宽度同样稳定。想始终
看到完整标题？关掉即可:

```
/media:config statusline.marquee off
```

### 颜色与逐项样式

组件默认带样式输出。Claude Code 的状态栏能渲染 ANSI 代码，wrapper 会
原样透传:

- ▶︎/⏸ 图标、进度条的填充部分和音量柱条都随播放状态变色（播放中绿色，暂停黄色）
- **加粗**的曲名和已播放时间（一直在走的部分保持清晰）、*斜体*的歌手、
  变暗的总时长、空白格、应用名和输出设备

用到的只有标准的 16 色 SGR 代码，所以最终色彩完全跟着你终端自己的配色走。
更喜欢纯文本？运行 `/media:config statusline.color off`——`NO_COLOR`
环境变量同样有效。

不止如此，**每个部分都能单独定制**。用 `/media:statusline` 的 Style
标签页，或直接一句话说出想要的效果（"曲名加粗青色"、"进度条换成 dots"、
"音量图标用 ♪"、"把歌手藏起来"），或者直接设置配置键。文本类的键接受
`bold dim italic underline` 的任意组合外加至多一种颜色（`black red green
yellow blue magenta cyan white` 或 `bright-<颜色>`），或者 `none`（完全
不加样式），或者 **`off`（隐藏这个部分）**:

| 键 | 对象 | 默认值 |
| --- | --- | --- |
| `style.track.title` / `style.track.artist` | 曲名 / 歌手 | `bold` / `italic` |
| `style.app` | 应用名 `(Spotify)` | `dim` |
| `style.time.elapsed` / `style.time.total` | `2:13` / `/4:24` | `bold` / `dim` |
| `style.volume.icon` / `style.volume.style` / `style.volume.bar` / `style.volume.percent` | 音量图标 / 柱条形状 / 柱条开关 / 百分比 | `auto` / `block` / `on` / `dim` |
| `style.progressbar.playing` / `style.progressbar.paused` | 进度条填充 + ▶︎/⏸ 强调色 | `green` / `yellow` |
| `style.progressbar.style` | 进度条字符 | `line` |
| `style.output.icon` / `style.output` | 输出图标 / 设备名 | `auto` / `dim` |

隐藏会连同周边一起收拾干净: 藏起曲名，`—` 分隔符也跟着消失；藏起已播放
时间，总时长前面的 `/` 也不再出现；一个条目的所有部分都被隐藏时，条目
本身也会消失。（要去掉整个条目属于排布的事——把它的数字从模式里去掉即可。）

进度条的字符由 `style.progressbar.style` 决定:

| 预设 | 外观 | |
|---|---|---|
| `line`（默认） | `━━━━━━────` | |
| `blocks` | `██████░░░░` | |
| `smooth` | `█████▋░░░░` | 边界格是 ⅛ 级的部分块 |
| `knob` | `━━━━━●────` | 滑块圆点标在填充末端 |
| `wave` | `▂▄▆▄▂▄▁▁▁▁` | 波浪——播放时滚动 |
| `pulse` | `▂▂█▁▄▂▁▁▁▁` | 心电图搏动——播放时滚动 |
| `eq` | `▂▇▃█▅▆▁▁▁▁` | 均衡器——播放时滚动 |
| `notes` | `♪♫♪♫♪♫····` | 音符——播放时行进 |
| `braille` | `⣿⣿⣿⣿⣿⣿⣀⣀⣀⣀` | |
| `chevron` | `▸▸▸▸▸▸▹▹▹▹` | |
| `tape` | `▰▰▰▰▰▰▱▱▱▱` | |
| `cassette` | `▮▮▮▮▮▮▯▯▯▯` | |
| `retro` | `======----` | 纯 ASCII |
| `dots` | `●●●●●●○○○○` | |

也可以用任意两个字符表示"填充 + 空白"（`"#-"` → `######----`）。动态预设
在播放时波形每秒向空白端滚动，暂停即停住。`/media:now` 回复里的进度条也用
同一组字符绘制，两处显示始终一致。音量柱条的形状由
`style.volume.style` 决定: `block`（一个随音量升降的 `▄`，默认）、
`progress`（用进度条字符画的 5 格迷你条）、`stairs`（`▂▄▆█` 阶梯）。
无论哪种形状，音量柱条都用进度条的播放/暂停颜色来画——整个组件只有一种
强调色，`style.volume.bar` 只是它的开关（默认 `on`）。图标
（`style.volume.icon`、`style.output.icon`）可以是 `auto`（按音量分级 /
按设备类型）、`none`（隐藏）或 `♪` 之类的任意字形；静音时始终显示 🔇。
改字符的键和 `off` 即使关掉颜色也生效，其余键需要 `statusline.color`
处于开启状态。

```
/media:config style.track.title "bold cyan"    # 只设置一个部分
/media:config style.track.title reset          # 单独恢复这一项的默认值
/media:config style reset                      # 所有样式恢复默认
/media:config statusline reset                 # 排布、分行、颜色、跑马灯、
                                               # 样式一并回到出厂外观
```

运行 `media.sh config style` 可以列出每个键的当前值和默认值。改动会在下一次
状态栏刷新时立即生效，无需重启。

## 手动设置（自定义状态栏）

更愿意自己掌管接线——比如把组件嵌进你自己的状态栏脚本*里面*，而不是
作为单独的一行追加？那就**先**把命令配置好，再开启组件: 自动接线能认出
已经在运行组件的 `statusLine` 命令（命令里提到 `statusline-media.sh`
或 `media.sh … statusline`），完全不去碰它——这时开启只是切换显示开关
而已。

一个可用作起点的通用 wrapper——存为 `~/.claude/statusline-media.sh`
并加上执行权限（`chmod +x ~/.claude/statusline-media.sh`）:

```bash
#!/bin/bash
# statusline-media.sh —— 原有状态栏（原样）+ 播放信息一行。
input=$(cat)

# ── 1. 把你原来的 statusLine 命令原样粘贴到引号之间。
#       就是 settings.json 里 "statusLine" 下面那个 "command" 的值。
#       如果之前没配过状态栏，EXISTING 留空即可。
EXISTING=''
if [ -n "$EXISTING" ]; then
  printf '%s' "$input" | bash -c "$EXISTING"
fi

# ── 2. 播放信息（关闭 / 没在播放 / 插件不存在时，什么都不输出）。
#       每次运行时都会找已安装的最新插件版本，所以插件更新后
#       wrapper 照常工作。
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

然后自己让 `~/.claude/settings.json` 指向它:

```json
{
  "statusLine": {
    "type": "command",
    "command": "\"$HOME/.claude/statusline-media.sh\"",
    "refreshInterval": 1
  }
}
```

（`refreshInterval: 1` 让时间和进度条在你不操作时也每秒都在走——见上文
"开启"。）在检出目录里开发（`claude --plugin-dir`）？把 `MEDIA_DIR`
那一块换成你的仓库路径:
`np="$(/path/to/claude-media-control/scripts/media.sh statusline 2>/dev/null)"`

## 维护提示

- **自动接线（managed）**: wrapper 是生成出来的文件——别手动改它；插件
  更新时（会话启动的 warm-up）以及重新运行 `media.sh statusline install`
  时都会重新生成。`media.sh statusline uninstall` 会拆掉接线并恢复你
  之前的状态栏；卸载插件后，下一次状态栏刷新时也会自动做同样的事。
- **手动接线（manual）**: 那些文件归你所有，插件绝不去碰。以后改了
  状态栏配置，记得把 `EXISTING` 那一行也同步改掉。想撤销，把
  `settings.json` 里的 `"statusLine"` 改回原值，再删掉你的 wrapper。
  只卸载插件的话，组件会自己安静下来（插件的配置随数据目录一起消失），
  但文件要你自己删。
- `/media:config display.statusline off` 立即生效——关闭的那一刻缓存的行
  就被删掉了，不用重启状态栏。
