# Statusline 스타일 갤러리

[English](styles.md) | **한국어** | [日本語](styles.ja.md) | [简体中文](styles.zh-CN.md)

재생 정보 세그먼트의 눈에 보이는 모든 것이 설정 키 하나씩입니다. 이 페이지는
**제공되는 스타일 전부를 실제 모습과 함께** 보여줍니다. 바꾸는 방법은 두 가지:

```
/media:statusline                              # 대화형 — 아니면 그냥 말로:
                                               #   "바 스타일 dots", "가수 숨겨줘"
/media:config style.progressbar.style wave     # 키를 직접 설정
```

변경은 다음 statusline 틱(1초 이내)에 바로 반영됩니다. 재시작은 없습니다.
`media.sh config style`을 실행하면 모든 키의 현재 값과 기본값이 나옵니다.

## 세그먼트 해부도

```
▶︎ Karma Police — Radiohead (Spotify)  🔉 ▄ 45%  ━━━━━━━━━━━━────────  2:13/4:24  🎧 AirPods Pro
```

| 보이는 것 | 키 | 기본값 |
| --- | --- | --- |
| `▶︎` / `⏸` 상태 아이콘 | 색은 `style.progressbar.playing` / `.paused`를 따름 | `green` / `yellow` |
| `Karma Police` | `style.track.title` | `bold` |
| `— Radiohead` | `style.track.artist` | `italic` |
| `(Spotify)` | `style.app` | `dim` |
| `🔉` 볼륨 아이콘 | `style.volume.icon` | `auto` |
| `▄` 볼륨 바 | `style.volume.style`(모양) · `style.volume.bar`(표시) | `block` · `on` |
| `45%` | `style.volume.percent` | `dim` |
| `━━━━━━━━━━━━────────` | `style.progressbar.style`(문자) · `style.progressbar.length`(칸 수) | `line` · `20` |
| `2:13` 경과 시간 | `style.time.elapsed` | `bold` |
| `/4:24` 총 시간 | `style.time.total` | `dim` |
| `🎧` 출력 아이콘 | `style.output.icon` | `auto` |
| `AirPods Pro` | `style.output` | `dim` |

(어떤 항목을 어느 줄에 놓을지는 *배치*의 일입니다 —
[statusline.ko.md](statusline.ko.md)를 보세요.)

세그먼트 전체에 **강조색 하나**가 흐릅니다: ▶︎/⏸ 아이콘, 진행 바의 채움,
볼륨 바가 모두 재생 중에는 `style.progressbar.playing`, 일시정지 중에는
`.paused` 색으로 그려집니다.

## 진행 바

`style.progressbar.style`이 문자를, `style.progressbar.length`가 바의
칸 수(기본 20)를 정합니다. `/media:now` 응답의 바도 같은 문자와 길이로
그려지므로 두 곳이 항상 같은 모습입니다. 문자와 길이는 색을 꺼 둔
상태에서도 적용됩니다.

![진행 바 프리셋과 볼륨 모양, 헥스 강조색이 1초에 한 프레임씩 실제로 움직이는 모습](styles.gif)

### 고정 프리셋

60% 기준입니다 (서브셀 프리셋은 부분 글리프가 보이도록 58%):

| 값 | 모양 | |
| --- | --- | --- |
| `line` | `━━━━━━━━━━━━────────` | 기본값 |
| `blocks` | `████████████░░░░░░░░` | 클래식 (0.12 이전 기본값) |
| `smooth` | `███████████▋░░░░░░░░` | 경계 칸이 부분 블록 — 아래 참고 |
| `rise` | `███████████▅░░░░░░░░` | 경계 칸이 아래에서 위로 차오름 — 아래 참고 |
| `fade` | `███████████▓░░░░░░░░` | 경계 칸이 ▒→▓로 짙어짐 — 아래 참고 |
| `corner` | `███████████▌░░░░░░░░` | 경계 칸이 사분면 단위로 채워짐 — 아래 참고 |
| `glide` | `━━━━━━━━━━━╾────────` | `line` 바의 반 칸 단위판 — 아래 참고 |
| `stipple` | `⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣶⣀⣀⣀⣀⣀⣀⣀⣀` | `braille` 바 + 점이 차오르는 경계 — 아래 참고 |
| `tiles` | `■■■■■■■■■■■◧□□□□□□□□` | 정사각 + 반 칸 채움 경계 — 아래 참고 |
| `dash` | `━━━━━━━━━━━╌┈┈┈┈┈┈┈┈` | 얇은 대쉬 트랙 위의 굵은 선 — 아래 참고 |
| `seam` | `━━━━━━━━━━━┄────────` | `line` 바 + 얇은 대쉬 경계 — 아래 참고 |
| `knob` | `━━━━━━━━━━━●────────` | 슬라이더 노브가 채움 끝을 표시 |
| `braille` | `⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣀⣀⣀⣀⣀⣀⣀⣀` | |
| `chevron` | `▸▸▸▸▸▸▸▸▸▸▸▸▹▹▹▹▹▹▹▹` | |
| `tape` | `▰▰▰▰▰▰▰▰▰▰▰▰▱▱▱▱▱▱▱▱` | |
| `cassette` | `▮▮▮▮▮▮▮▮▮▮▮▮▯▯▯▯▯▯▯▯` | |
| `retro` | `============--------` | 순수 ASCII |
| `dots` | `●●●●●●●●●●●●○○○○○○○○` | |

`smooth`는 ⅛칸 단위로 차오르기 때문에 짧은 곡에서도 초 사이의 진행이
눈에 보입니다:

```
 3%  ▋░░░░░░░░░░░░░░░░░░░
47%  █████████▍░░░░░░░░░░
98%  ███████████████████▋
```

`rise`는 같은 ⅛ 단위를 아래에서 위로 쌓습니다 — 각 칸이 ▁▂▃▄▅▆▇를
거쳐 완성됩니다:

```
 3%  ▅░░░░░░░░░░░░░░░░░░░
47%  █████████▃░░░░░░░░░░
98%  ███████████████████▅
```

나머지 일곱 서브셀 프리셋도 같은 부분 경계 방식을 각자의 해상도로
사용합니다 — fade·dash는 ⅓, corner·seam은 ¼, stipple은 ⅙,
glide·tiles는 ½ 단위:

```
fade     47%  █████████▒░░░░░░░░░░      98%  ███████████████████▓
corner   46%  █████████▖░░░░░░░░░░      99%  ███████████████████▙
glide    47%  ━━━━━━━━━╾──────────      98%  ━━━━━━━━━━━━━━━━━━━╾
stipple  46%  ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣄⣀⣀⣀⣀⣀⣀⣀⣀⣀⣀      99%  ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷
tiles    47%  ■■■■■■■■■◧□□□□□□□□□□      98%  ■■■■■■■■■■■■■■■■■■■◧
dash     47%  ━━━━━━━━━┄┈┈┈┈┈┈┈┈┈┈      98%  ━━━━━━━━━━━━━━━━━━━╌
seam     46%  ━━━━━━━━━┈──────────      99%  ━━━━━━━━━━━━━━━━━━━╌
```

### 움직이는 프리셋

이 네 가지는 재생 중에 파형이 1초에 한 칸씩 빈 쪽으로 흘러가고,
일시정지하면 멈춥니다:

| 값 | t | t+1초 | t+2초 | |
| --- | --- | --- | --- | --- |
| `wave` | `▂▄▆▄▂▄▆▄▂▄▆▄▁▁▁▁▁▁▁▁` | `▄▂▄▆▄▂▄▆▄▂▄▆▁▁▁▁▁▁▁▁` | `▆▄▂▄▆▄▂▄▆▄▂▄▁▁▁▁▁▁▁▁` | 넘실대는 물결 |
| `pulse` | `▂▂█▁▄▂▂█▁▄▂▂▁▁▁▁▁▁▁▁` | `▄▂▂█▁▄▂▂█▁▄▂▁▁▁▁▁▁▁▁` | `▁▄▂▂█▁▄▂▂█▁▄▁▁▁▁▁▁▁▁` | 심전도 박동 |
| `eq` | `▂▇▃█▅▆▂▇▃█▅▆▁▁▁▁▁▁▁▁` | `▆▂▇▃█▅▆▂▇▃█▅▁▁▁▁▁▁▁▁` | `▅▆▂▇▃█▅▆▂▇▃█▁▁▁▁▁▁▁▁` | 이퀄라이저 |
| `notes` | `♪♫♪♫♪♫♪♫♪♫♪♫········` | `♫♪♫♪♫♪♫♪♫♪♫♪········` | `♪♫♪♫♪♫♪♫♪♫♪♫········` | 행진하는 음표 |

### 나만의 문자

**정확히 두 글자**를 주면 "채움 + 빈칸"이 됩니다 (빈칸 자리에 공백도
됩니다. 공백 두 개, 탭, 줄바꿈은 거부):

```
/media:config style.progressbar.style "#-"     →  ############--------
/media:config style.progressbar.style "~ "     →  ~~~~~~~~~~~~
```

### 바 길이

`style.progressbar.length`가 바가 차지하는 칸 수를 정합니다 — 1에서 60
사이의 정수, 기본값 `20`:

```
/media:config style.progressbar.length 10   →  ━━━━━━────
/media:config style.progressbar.length 40   →  ━━━━━━━━━━━━━━━━━━━━━━━━────────────────
```

길이 하나가 statusline 세그먼트와 `/media:now` 응답의 바를 함께
움직입니다. 링크가 켜져 있으면 모든 칸이 그대로 ⌘+클릭 대상이라, 바가
길수록 그만큼 촘촘하게 탐색됩니다. (볼륨 미니 바는 볼륨 단계당 한 칸씩,
8칸 고정입니다.) 기본값은 0.20.0에서 10칸에서 20칸으로 늘었습니다 —
`10`으로 설정하면 이전의 짧은 바로 돌아갑니다.

### 바 색상

`style.progressbar.playing`(기본 `green`)과 `.paused`(기본 `yellow`)가
채움 색을 정합니다 — 세그먼트가 강조색 하나를 공유하므로 ▶︎/⏸ 아이콘과
볼륨 바도 함께 바뀝니다. 빈 칸은 항상 흐리게 유지됩니다.

```
/media:config style.progressbar.playing bright-cyan
/media:config style.progressbar.playing "#1db954"   # 어떤 헥스 색이든
/media:config style.progressbar.paused magenta
```

## 볼륨

`volume` 항목은 **아이콘 + 바 + 퍼센트**(`🔉 ▄ 45%`)로 그려지고, 음소거
중에는 `🔇` 하나로 접힙니다. (네이티브 helper가 필요합니다 —
`/media:doctor` 참고.)

### 바 모양 — `style.volume.style`

| 값 | 10% | 20% | 35% | 50% | 60% | 75% | 85% | 100% | |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `block` | `▁` | `▂` | `▃` | `▄` | `▅` | `▆` | `▇` | `█` | 한 칸, 높이 = 볼륨 (기본값) |
| `stairs` | `▁` | `▁▂` | `▁▂▃` | `▁▂▃▄` | `▁▂▃▄▅` | `▁▂▃▄▅▆` | `▁▂▃▄▅▆▇` | `▁▂▃▄▅▆▇█` | 8단 계단 |
| `progress` | `━───────` | `━━──────` | `━━━─────` | `━━━━────` | `━━━━━───` | `━━━━━━──` | `━━━━━━━─` | `━━━━━━━━` | 8칸 미니 바 |

`progress`는 진행 바의 문자로 그려집니다 — 애니메이션까지 그대로.
`blocks`면 `████░░░░`, `dots`면 `●●●●○○○○`. 볼륨 바의 색은 언제나
재생/일시정지 강조색을 따르고, `style.volume.bar off`는 바만
숨깁니다(`🔉 45%`).

### 볼륨 아이콘 — `style.volume.icon`

| 값 | 모양 |
| --- | --- |
| `auto` (기본값) | `🔈` 낮음 · `🔉` 중간 · `🔊` 높음 · `🔇` 0일 때 |
| `none` | 숨김 — `▄ 45%` |
| 아무 글리프, 예: `♪` | `♪ ▄ 45%` |

음소거 중에는 아이콘 설정과 무관하게 항상 `🔇`가 나옵니다.

### 퍼센트 — `style.volume.percent`

텍스트 스타일(기본 `dim`)을 받고, `off`면 빠집니다: `🔉 ▄`.

## 출력 장치

`output` 항목은 아이콘 + 장치 이름입니다: `🎧 AirPods Pro`.

| 키 | 값 |
| --- | --- |
| `style.output.icon` | `auto`(기본값) = 장치 종류별: `🎧` Bluetooth·헤드폰 잭 · `📺` HDMI/DisplayPort · `📶` AirPlay · `🔊` 스피커 — 또는 `none`, 또는 아무 글리프 |
| `style.output` | 장치 이름의 텍스트 스타일(기본 `dim`), `off`면 아이콘만 |

## 텍스트 스타일

텍스트로 된 모든 부분 — 제목, 아티스트, 앱, 경과/총 시간, 볼륨 퍼센트,
출력 장치 이름 — 은 **스타일 스펙**을 받습니다:

- `bold`, `dim`, `italic`, `underline` 중 몇 개든
- 색은 최대 하나: `black` `red` `green` `yellow` `blue` `magenta` `cyan`
  `white`, `bright-<색>` (실제 색감은 터미널 팔레트가 정합니다), 또는
  정확한 헥스 코드 — `#ff8800`, 짧게 `#f80` — 24-bit 트루컬러로
  렌더링됩니다 (대부분의 터미널이 지원하지만 Apple Terminal은 미지원)
- 또는 `none` — 스타일 없음
- 또는 `off` — **그 부분을 숨김**

```
/media:config style.track.title "bold bright-cyan"
/media:config style.track.title "bold #ff8800"   # 정확한 색 — 헥스는 따옴표로
/media:config style.track.artist off
```

숨김은 주변도 함께 정리합니다: 제목을 숨기면 `—` 구분자도 사라지고, 경과
시간을 숨기면 총 시간 앞의 `/`도 사라지며, 모든 부분이 숨겨진 항목은
통째로 사라집니다. (항목 하나를 아예 빼는 건 배치의 일입니다 —
`/media:statusline`.)

스타일 스펙은 `statusline.color`가 켜져 있을 때만 그려집니다(`NO_COLOR`가
항상 우선). 문자를 바꾸는 것들 — 바 문자, 볼륨 바 모양, 아이콘 — 과
`off`는 색과 무관하게 적용됩니다.

## 레시피

바로 붙여넣을 수 있는 네 가지 룩입니다. 색은 이 페이지에 안 보이니
statusline에서 직접 확인하세요.

**미니멀** — 제목과 경과 시간만:

```
/media:config statusline.fields "track,time"
/media:config style.track.artist off
/media:config style.time.total off
```
```
▶︎ Karma Police  2:13
```

**나이트 드라이브** — 네온 dots + 시안 제목:

```
/media:config style.progressbar.style dots
/media:config style.progressbar.playing bright-magenta
/media:config style.track.title "bold bright-cyan"
```
```
▶︎ Karma Police — Radiohead (Spotify)  ●●●●●●●●●●●●○○○○○○○○  2:13/4:24
```

**테이프 데크** — 테이프 바, 계단 볼륨, 음표 아이콘:

```
/media:config statusline.fields "track,app,volume,progressbar,time"
/media:config style.progressbar.style tape
/media:config style.volume.style stairs
/media:config style.volume.icon ♪
```
```
▶︎ Karma Police — Radiohead (Spotify)  ♪ ▁▂▃▄ 45%  ▰▰▰▰▰▰▰▰▰▰▰▰▱▱▱▱▱▱▱▱  2:13/4:24
```

**순수 터미널** — ASCII 바, 색 없음:

```
/media:config style.progressbar.style retro
/media:config statusline.color off
```
```
▶︎ Karma Police — Radiohead (Spotify)  ============--------  2:13/4:24
```

## 기본값으로 되돌리기

```
/media:config style.track.title reset     # 키 하나만
/media:config style reset                 # 모든 style.* 키
/media:config statusline reset            # 스타일 + 배치·줄·색·marquee까지
                                          # 통째로 기본 모습으로
```
