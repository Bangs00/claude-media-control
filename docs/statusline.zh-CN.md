# 在状态栏中显示 now-playing

[English](statusline.md) | [한국어](statusline.ko.md) | [日本語](statusline.ja.md) | **简体中文**

把当前曲目作为额外一行显示在 Claude Code 的状态栏中:

```
[你现有的状态栏，原样保留]
▶︎ Karma Police — Radiohead  ██████░░░░  2:13/4:24
```

这一区块由 `media.sh statusline` 输出，它从一个小型 TTL 缓存（默认 1 秒）
应答，耗时远低于 50ms — 绝不会拖慢你的状态栏。真正的 now-playing 读取在
每个 TTL 窗口内最多执行一次，因此状态栏重绘时，经过时间和进度条大约每秒
前进一次。

## 设计保证（为什么可以放心添加）

1. 你现有的状态栏命令**不会被替换** — wrapper 会先原样执行它。
2. 它的输出**逐字节原样**通过。
3. now-playing 只会**作为独立一行追加**。
4. 当 `display.statusline` 关闭时（默认），区块命令不输出任何内容 —
   连空行都没有。Claude Code 会折叠缺失的行，所以状态栏看起来和以前
   一模一样。

插件永远不会替你编辑 `settings.json`；下面的每一步都是手动的、可撤销的
编辑。

## 第 1 步 — 启用区块

在 Claude Code 中:

```
/media:config display.statusline on
```

（启用时会先验证 now-playing 读取路径可用；如果被拒绝，请运行
`/media:doctor`。）

### 选择区块显示的内容

运行 `/media:statusline` 选择显示哪些项以及如何排布:

- **显示项**（任意组合）: `track`（▶︎ 标题 — 艺人）、`progressbar`
  （`██████░░░░`）、`time`（`2:13/4:24`）、`spectrum`（实时频率条）。
  全选即显示全部。
- **布局**: 单行，或每组独立一行（`statusline.multiline`）。

单行显示全部项:

```
▶︎ Karma Police — Radiohead  ██████░░░░  2:13/4:24  ▂▄▆█▇▅▃▂
```

多行（`statusline.multiline on`）:

```
▶︎ Karma Police — Radiohead
██████░░░░  2:13/4:24
▂▄▆█▇▅▃▂
```

`spectrum` 项需要手动开启，依赖 `display.spectrum on` 和系统音频录制权限
（见 `/media:spectrum`）。它每次刷新会捕获约 0.5 秒音频，比其他项更重 —
想要最轻量的状态栏就不要选它。

### 颜色

区块默认带样式输出 — Claude Code 状态栏可以渲染 ANSI 代码，下面的 wrapper
会原样透传:

- 图标和进度条的填充部分跟随播放状态（播放中绿色，暂停黄色）
- **加粗**的标题、*斜体*的艺人、变暗的时间和空白进度格
- 频谱条按 `spectrum.style` 着色:
  - `solid`（默认）— 所有条同一颜色，用 `spectrum.color` 选择
    （`red green yellow blue magenta cyan white`，默认 `cyan`）
  - `rainbow` — 按条位置从前到后的固定色彩循环（绝不随音量变化），
    每秒推进一步；`spectrum.color` 被忽略

```
/media:config spectrum.style rainbow
/media:config spectrum.color magenta
```

只使用标准 16 色 SGR 代码，所以一切颜色都遵循你终端自己的配色。喜欢纯文本？
运行 `/media:config statusline.color off` — `NO_COLOR` 环境变量同样有效。

## 第 2 步 — 创建 wrapper 脚本

保存为 `~/.claude/statusline-media.sh` 并赋予执行权限
（`chmod +x ~/.claude/statusline-media.sh`）:

```bash
#!/bin/bash
# statusline-media.sh — 现有状态栏（原样）+ now-playing 行。
input=$(cat)

# ── 1. 把你现有的 statusLine 命令原样粘贴到引号之间。
#       从 settings.json 中 "statusLine" 下的 "command" 值获取。
#       如果之前没有状态栏，就让 EXISTING 保持为空。
EXISTING=''
if [ -n "$EXISTING" ]; then
  printf '%s' "$input" | bash -c "$EXISTING"
fi

# ── 2. now-playing（关闭 / 无播放 / 插件不存在时输出为空）。
#       运行时解析已安装的最新插件版本，因此 wrapper 在插件更新后
#       仍然有效。
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

从检出目录开发（`claude --plugin-dir`）？把 `MEDIA_DIR` 代码块替换为你的
仓库路径:
`np="$(/path/to/claude-media-control/scripts/media.sh statusline 2>/dev/null)"`。

## 第 3 步 — 让 settings.json 指向 wrapper

在 `~/.claude/settings.json` 中:

```json
{
  "statusLine": {
    "type": "command",
    "command": "\"$HOME/.claude/statusline-media.sh\""
  }
}
```

**想要"活"的状态栏，推荐:** 在 `"command"` 旁边加上
`"refreshInterval": 1`。状态栏通常只在会话事件时刷新，所以你空闲时经过
时间和进度条会停住。`refreshInterval` 让命令周期性重跑；`1`（最小值）与
区块的 1 秒缓存配合，时间和进度条每秒走动一次。想减少重绘就去掉它或调大
数值（每次重绘也会重跑你现有的状态栏命令）。

## 维护说明

- wrapper 在 `EXISTING` 中保存的是你之前状态栏命令的**副本**。以后如果
  改动了状态栏配置，记得同步更新这一行。
- 想全部撤销: 恢复 `settings.json` 中原来的 `"statusLine"` 值，并删除
  `~/.claude/statusline-media.sh`。仅卸载插件也能让区块自行消失（插件
  不存在时 wrapper 不输出任何内容），但 wrapper 文件本身需要你自己删除。
- 区块会立即响应 `/media:config display.statusline off` — 停用时缓存的
  行会被删除，无需重启状态栏。
