# 把正在播放的歌放进状态栏

[English](statusline.md) | [한국어](statusline.ko.md) | [日本語](statusline.ja.md) | **简体中文**

在 Claude Code 的状态栏里加一行，显示当前播放的曲目:

```
[你原来的状态栏，原样保留]
▶︎ Karma Police — Radiohead  ██████░░░░  2:13/4:24
```

这一行由 `media.sh statusline` 生成。它从一个小的 TTL 缓存（默认 1 秒）
应答，耗时远低于 50ms——绝不会拖慢你的状态栏。真正的播放信息读取在每个
TTL 窗口内最多执行一次，所以状态栏每次重绘时，经过时间和进度条大约每秒
往前走一格。

## 设计上的保证（为什么可以放心加）

1. 你原来的状态栏命令**不会被替换**——wrapper 会先原样执行它。
2. 它的输出**逐字节原样**透传。
3. 播放信息只会**作为单独的一行追加**在后面。
4. `display.statusline` 关闭时（默认就是关的），这个组件什么都不输出——
   连空行都没有。Claude Code 会自动收起不存在的行，所以状态栏看起来和
   原来一模一样。

插件从不替你改 `settings.json`；下面每一步都是手动的、随时可以撤销的修改。

## 第 1 步——启用组件

在 Claude Code 里:

```
/media:config display.statusline on
```

（开启前会先验证播放信息确实读得到；如果被拒绝，跑一下 `/media:doctor`。）

### 选择要显示的内容

运行 `/media:config`，选择显示哪些项、怎么排布:

- **显示项**（随意组合）: `track`（▶︎ 曲名 — 歌手）、`app`（正在播放的
  应用，如 `(Spotify)`）、`progressbar`（`██████░░░░`）、`time`
  （`2:13/4:24`）、`output`（🔊 当前音频输出设备）、`spectrum`（实时频谱
  柱）。默认组合是 `track app progressbar time`。
- **布局**: 并成一行，或者每组各占一行（`statusline.multiline`）。

所有内容放一行:

```
▶︎ Karma Police — Radiohead (Spotify)  ██████░░░░  2:13/4:24  🔊 AirPods Pro  ▂▄▆█▇▅▃▂
```

分行显示（`statusline.multiline on`）:

```
▶︎ Karma Police — Radiohead (Spotify)
██████░░░░  2:13/4:24
🔊 AirPods Pro
▂▄▆█▇▅▃▂
```

`output` 这一项需要原生 helper（它搭载在组件本来就要做的那次读取上，
不产生额外开销）。切换设备用 `/media:output`，组件会在下一次刷新时更新。

`spectrum` 这一项需要手动开启，依赖 `display.spectrum on` 和系统音频录制
权限（见 `/media:spectrum`）。它每次刷新都要捕获约 0.5 秒的声音，比其他
项都重——想让状态栏尽可能轻量的话，就别选它。

### 长标题: 跑马灯滚动

超过 30 个终端单元格宽的标题，会在固定 30 格的窗口里以每秒一个字符的速度
滚动（与下文的 1 秒刷新联动，每次重绘前进一格）:

```
▶︎ ing Willow (10 Minute Version)  — Taylor Swift (Music)
```

汉字、假名、谚文都按两格计算，所以中日韩标题的窗口宽度同样稳定。想始终
看到完整标题？关掉即可:

```
/media:config statusline.marquee off
```

### 颜色

组件默认带样式输出。Claude Code 的状态栏能渲染 ANSI 代码，下面的 wrapper
会原样透传:

- 图标和进度条的填充部分随播放状态变色（播放中绿色，暂停黄色）
- **加粗**的曲名、*斜体*的歌手、变暗的时间、空白格、应用名和输出设备
- 频谱柱的颜色由 `spectrum.style` 决定:
  - `solid`（默认）——所有柱子同一个颜色，用 `spectrum.color` 挑
    （`red green yellow blue magenta cyan white`，默认 `cyan`）
  - `rainbow`——按柱子位置从前到后固定循环（与音量无关），每秒往前走
    一步；此时 `spectrum.color` 会被忽略

```
/media:config spectrum.style rainbow
/media:config spectrum.color magenta
```

用到的只有标准的 16 色 SGR 代码，所以最终色彩完全跟着你终端自己的配色走。
更喜欢纯文本？运行 `/media:config statusline.color off`——`NO_COLOR`
环境变量同样有效。

## 第 2 步——创建 wrapper 脚本

把下面的内容存为 `~/.claude/statusline-media.sh` 并加上执行权限
（`chmod +x ~/.claude/statusline-media.sh`）:

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

在检出目录里开发（`claude --plugin-dir`）？把 `MEDIA_DIR` 那一块换成你的
仓库路径:
`np="$(/path/to/claude-media-control/scripts/media.sh statusline 2>/dev/null)"`

## 第 3 步——让 settings.json 指向 wrapper

在 `~/.claude/settings.json` 里:

```json
{
  "statusLine": {
    "type": "command",
    "command": "\"$HOME/.claude/statusline-media.sh\""
  }
}
```

**想让状态栏"活"起来，推荐**在 `"command"` 旁边加上
`"refreshInterval": 1`。状态栏平时只在会话有动静时才刷新，所以你不操作的
时候，经过时间和进度条是停着的。加上 `refreshInterval` 后命令会定期重跑；
最小值 `1` 正好和组件的 1 秒缓存对上，时间和进度条每秒都在走。想少刷新
几次就去掉它或调大数值（每次重绘也会连带重跑你原来的状态栏命令）。

## 维护提示

- wrapper 的 `EXISTING` 里存的是你之前状态栏命令的**副本**。以后改了
  状态栏配置，记得把这一行也同步改掉。
- 想全部还原: 把 `settings.json` 里的 `"statusLine"` 改回原值，删掉
  `~/.claude/statusline-media.sh`。只卸载插件的话，这一行也会自己消失
  （插件不在了，wrapper 就什么都不输出），但 wrapper 文件本身要你自己删。
- `/media:config display.statusline off` 立即生效——关闭的那一刻缓存的行
  就被删掉了，不用重启状态栏。
