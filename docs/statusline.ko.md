# statusline에 재생 중인 곡 띄우기

[English](statusline.md) | **한국어** | [日本語](statusline.ja.md) | [简体中文](statusline.zh-CN.md)

Claude Code statusline에 현재 곡을 한 줄 추가해 보여줍니다:

```
[기존 statusline은 그대로]
▶︎ Karma Police — Radiohead  ━━━━━━────  2:13/4:24
```

이 줄은 `media.sh statusline`이 만들어 냅니다. 작은 TTL 캐시(기본 1초)에서
50ms도 안 걸려 응답하기 때문에 statusline이 느려질 일은 없습니다. 실제 재생
정보 조회는 TTL 구간마다 최대 한 번만 일어나므로, statusline이 다시 그려질
때 경과 시간과 진행 바는 대략 1초에 한 번씩 갱신됩니다.

## 설계상 보장되는 것 (안심하고 추가해도 되는 이유)

1. 기존 statusline 명령은 **대체되지 않습니다**. wrapper가 기존 명령을 원래
   모습 그대로 먼저 실행합니다.
2. 그 출력은 **한 바이트도 바뀌지 않고** 그대로 통과합니다.
3. 재생 정보는 언제나 **별도의 줄로만 덧붙습니다**.
4. `display.statusline`이 꺼져 있으면(기본값) 세그먼트 명령은 아무것도
   출력하지 않습니다. 빈 줄조차 없습니다. Claude Code가 없는 줄을 접어
   주기 때문에 statusline은 이전과 똑같이 보입니다.

플러그인이 `settings.json`을 대신 고치는 일은 없습니다. 아래 과정은 전부
직접 하는, 언제든 되돌릴 수 있는 수정입니다.

## 1단계 — 세그먼트 켜기

Claude Code 안에서:

```
/media:config display.statusline on
```

(켜기 전에 재생 정보를 실제로 읽을 수 있는지 먼저 검증합니다. 거부되면
`/media:doctor`를 실행해 보세요.)

### 항목 배치하기

`/media:statusline`을 실행하세요 — 세그먼트의 모습을 한 곳에서 정하는
허브입니다. 탭 세 개가 열립니다: **Items**(볼륨·진행 바·시간·출력 장치
켜고 끄기), **Layout**(Standard / Stacked 또는 숫자 패턴),
**Style**(항목별 스타일 — 다음 절). 패턴은 아래 범례로 만듭니다:

| # | 항목 | 표시 예 |
| --- | --- | --- |
| 1 | `track` | `▶︎ Karma Police — Radiohead` |
| 2 | `app` | `(Spotify)` |
| 3 | `volume` | `🔉 ▄ 45%` — 아이콘 + 볼륨량 높이 바 + 퍼센트, 음소거면 `🔇` |
| 4 | `progressbar` | `━━━━━━────` |
| 5 | `time` | `2:13/4:24` |
| 6 | `output` | `🎧 AirPods Pro` — 아이콘은 장치 종류를 따름: `🎧` Bluetooth·헤드폰 잭 · `📺` HDMI/DisplayPort · `📶` AirPlay · `🔊` 스피커 |

숫자 순서가 곧 표시 순서입니다. `/`는 새 줄을 시작합니다. 뺀 숫자의 항목은
표시되지 않습니다. 예를 들어 `123/456`은 1번째 줄에 track·app·볼륨, 2번째
줄에 나머지를 놓습니다. 기본 구성은 `track app progressbar time`이고, 켜고
끄는 빠른 토글과 statusline 전체 초기화는 `/media:config`에 있습니다.

배치가 동작하는 방식:

- **순서** — 항목은 저장한 순서 그대로 그려집니다. "시간을 맨 앞에"라고
  말해도 되고, 목록을 직접 지정할 수도 있습니다:
  `/media:config statusline.fields "time,progressbar,track,app"`.
- **줄 단위 명시 배치** — 항목 목록에 `/`를 넣으면 그 자리에서 줄이
  바뀝니다. 각 줄에는 거기에 둔 항목만 그 순서대로 나옵니다. 보여줄 것이
  없는 줄은 통째로 사라집니다(예: 네이티브 helper가 없을 때의 `output`).
- **그룹 배치** (목록에 `/`가 없을 때) — 한 줄로 붙이거나,
  `statusline.multiline on`이면 그룹마다 줄을 나눕니다. 그룹 규칙: `app`은
  track에 붙습니다. `progressbar`와 `time`은 이웃할 때 한 그룹이 됩니다.
  `output`과 `volume`은 이웃한 track 그룹에 합류하고, 서로 이웃하면 둘이
  한 그룹이 됩니다.

Standard — 모든 항목을 한 줄로(패턴 `123456`):

```
▶︎ Karma Police — Radiohead (Spotify)  🔉 ▄ 45%  ━━━━━━────  2:13/4:24  🎧 AirPods Pro
```

Stacked — 명시적 2줄 배치(패턴 `123/456`, 즉
`statusline.fields "track,app,volume,/,progressbar,time,output"`):

```
▶︎ Karma Police — Radiohead (Spotify)  🔉 ▄ 45%
━━━━━━────  2:13/4:24  🎧 AirPods Pro
```

출력 장치를 track 줄에, 볼륨은 빼고(패턴 `126/45`):

```
▶︎ Karma Police — Radiohead (Spotify)  🎧 AirPods Pro
━━━━━━────  2:13/4:24
```

시간을 앞으로, 한 줄(패턴 `5412`, 즉
`statusline.fields "time,progressbar,track,app"`):

```
2:13/4:24  ━━━━━━────  ▶︎ Karma Police — Radiohead (Spotify)
```

`output`과 `volume` 항목은 네이티브 helper가 필요합니다(세그먼트가 원래
하던 조회에 함께 실려 오기 때문에 추가 비용은 없습니다). 장치 전환은
`/media:output`, 볼륨 조절은 `/media:volume`으로 하면 되고, 세그먼트는
다음 갱신 때 바로 반영됩니다.

### 긴 제목: marquee 스크롤

30칸(터미널 셀)보다 긴 제목은 고정된 30칸 창 안에서 1초에 한 글자씩
흘러갑니다. (창은 다시 그려질 때마다 한 칸씩 전진합니다 — 아래의 1초
갱신 주기 참고.)

```
▶︎ ing Willow (10 Minute Version)  — Taylor Swift (Music)
```

한글·한자·가나 문자는 두 칸으로 계산하므로 CJK 제목에서도 창 너비가
일정하게 유지됩니다. 아무리 길어도 제목 전체를 보고 싶다면 끄면 됩니다:

```
/media:config statusline.marquee off
```

### 색상과 항목별 스타일

세그먼트는 기본으로 스타일이 입혀져 나옵니다. Claude Code statusline은 ANSI
코드를 렌더링하고, 아래 wrapper는 이를 손대지 않고 그대로 넘깁니다:

- ▶︎/⏸ 아이콘, 진행 바의 채워진 부분, 볼륨 바는 재생 상태를 따라 색이
  바뀝니다 (재생 중 green, 일시정지 yellow)
- **굵은** 제목과 경과 시간(계속 움직이는 부분이라 또렷하게 보입니다),
  *기울임꼴* 아티스트, 흐리게 표시되는 전체 시간·빈 칸·앱 이름·출력 장치

표준 16색 SGR 코드만 쓰기 때문에 실제 색은 터미널의 팔레트를 따릅니다.
색 없이 쓰고 싶다면 `/media:config statusline.color off`를 실행하세요.
`NO_COLOR` 환경 변수도 지원합니다.

여기서 더 나아가 **모든 부분을 하나하나 따로 꾸밀 수 있습니다**.
`/media:statusline`의 Style 탭을 쓰거나, 원하는 모습을 그냥 말로
하거나("제목은 굵은 하늘색", "바 스타일은 dots", "볼륨 아이콘은 ♪", "가수는
숨겨줘"), 키를 직접 설정하면 됩니다. 텍스트 키는 `bold dim italic
underline` 조합에 색 하나(`black red green yellow blue magenta cyan white`
또는 `bright-<색>`)를 더하거나, `none`(스타일 없음), 또는 **`off`(그 부분
숨김)**를 받습니다:

| 키 | 대상 | 기본값 |
| --- | --- | --- |
| `style.track.title` / `style.track.artist` | 제목 / 아티스트 | `bold` / `italic` |
| `style.app` | 앱 이름 `(Spotify)` | `dim` |
| `style.time.elapsed` / `style.time.total` | `2:13` / `/4:24` | `bold` / `dim` |
| `style.volume.icon` / `style.volume.style` / `style.volume.bar` / `style.volume.percent` | 볼륨 아이콘 / 바 모양 / 바 표시 여부 / 퍼센트 | `auto` / `block` / `on` / `dim` |
| `style.progressbar.playing` / `style.progressbar.paused` | 바 채움 + ▶︎/⏸ 강조색 | `green` / `yellow` |
| `style.progressbar.style` | 진행 바 문자 | `line` |
| `style.output.icon` / `style.output` | 출력 아이콘 / 장치 이름 | `auto` / `dim` |

숨김은 그 부분의 주변까지 함께 정리됩니다: 제목을 숨기면 `—` 구분자도
사라지고, 경과 시간을 숨기면 총 시간 앞의 `/`도 사라지며, 한 항목의 모든
부분이 숨겨지면 항목 자체가 사라집니다. (항목 하나를 통째로 빼는 건 배치의
일입니다 — 패턴에서 그 숫자를 빼세요.)

진행 바의 문자는 `style.progressbar.style`이 정합니다: `line`
`━━━━━━────`(기본값) · `blocks` `██████░░░░` · `wave` `~~~~~~----` · `dots`
`●●●●●●○○○○`, 또는 "채움 + 빈칸"을 뜻하는 아무 두 글자(`"#-"` →
`######----`). `/media:now` 응답의 진행 바도 같은 문자로 그려지기 때문에 두
곳의 바가 항상 같은 모습입니다. 볼륨 바의 모양은
`style.volume.style`입니다: `block`(볼륨에 따라 높이가 변하는 `▄` 하나,
기본값), `progress`(진행 바 문자로 그리는 5칸 미니 바),
`stairs`(`▂▄▆█` 계단). 모양이 무엇이든 볼륨 바의 색은 진행 바의
재생/일시정지 색을 따라갑니다 — 세그먼트 전체가 하나의 강조색을 쓰는
것이고, `style.volume.bar`는 바를 켜고 끄는 스위치일 뿐입니다(기본 `on`).
아이콘(`style.volume.icon`,
`style.output.icon`)은 `auto`(레벨별 / 장치 종류별), `none`(숨김), 또는
`♪` 같은 아무 글리프이며, 음소거 시에는 항상 🔇가 나옵니다. 문자를 바꾸는
키와 `off`는 색을 꺼도 적용되고, 나머지 키는 `statusline.color`가 켜져
있어야 보입니다.

```
/media:config style.track.title "bold cyan"    # 한 부분만 설정
/media:config style.track.title reset          # 그 부분만 기본값으로
/media:config style reset                      # 스타일 전부 기본값으로
/media:config statusline reset                 # 배치·줄·색·marquee·스타일까지
                                               # 통째로 기본 모습으로
```

`media.sh config style`을 실행하면 모든 키의 현재 값과 기본값이 나옵니다.
변경은 다음 statusline 틱에 바로 반영되며 재시작은 필요 없습니다.

## 2단계 — wrapper 스크립트 만들기

아래 내용을 `~/.claude/statusline-media.sh`로 저장하고 실행 권한을 주세요
(`chmod +x ~/.claude/statusline-media.sh`):

```bash
#!/bin/bash
# statusline-media.sh — 기존 statusline(그대로) + 재생 정보 한 줄.
input=$(cat)

# ── 1. 기존에 쓰던 statusLine 명령을 따옴표 안에 그대로 붙여넣으세요.
#       settings.json의 "statusLine" 아래 "command" 값을 가져오면 됩니다.
#       원래 statusline이 없었다면 EXISTING을 빈 값으로 두세요.
EXISTING=''
if [ -n "$EXISTING" ]; then
  printf '%s' "$input" | bash -c "$EXISTING"
fi

# ── 2. 재생 정보 (꺼져 있거나 / 재생이 없거나 / 플러그인이 없으면 아무것도
#       출력하지 않습니다). 실행 시점에 설치된 최신 플러그인 버전을 찾기
#       때문에 플러그인을 업데이트해도 wrapper는 계속 동작합니다.
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

체크아웃한 리포에서 개발 중이라면(`claude --plugin-dir`) `MEDIA_DIR` 블록을
리포 경로로 바꾸면 됩니다:
`np="$(/path/to/claude-media-control/scripts/media.sh statusline 2>/dev/null)"`

## 3단계 — settings.json이 wrapper를 가리키게 하기

`~/.claude/settings.json`에서:

```json
{
  "statusLine": {
    "type": "command",
    "command": "\"$HOME/.claude/statusline-media.sh\""
  }
}
```

**실시간처럼 움직이는 statusline을 원한다면** `"command"` 옆에
`"refreshInterval": 1`을 추가하는 것을 추천합니다. statusline은 원래 대화
이벤트가 있을 때만 갱신되기 때문에, 가만히 있는 동안에는 경과 시간과 진행
바가 멈춰 있습니다. `refreshInterval`을 주면 명령을 주기적으로 다시
실행하는데, 최솟값인 `1`이 세그먼트의 1초 캐시와 맞물려 시간과 진행 바가
매초 움직입니다. 다시 그리는 횟수를 줄이고 싶다면 빼거나 값을 올리세요
(다시 그릴 때마다 기존 statusline 명령도 함께 실행됩니다).

## 관리 팁

- wrapper의 `EXISTING`에 들어 있는 것은 이전 statusline 명령의
  **복사본**입니다. 나중에 statusline 구성을 바꾸면 이 줄도 같이
  고쳐 주세요.
- 전부 되돌리려면: `settings.json`의 `"statusLine"` 값을 원래대로 복원하고
  `~/.claude/statusline-media.sh`를 지우면 됩니다. 플러그인만 제거해도
  세그먼트는 알아서 사라지지만(플러그인이 없으면 wrapper가 아무것도
  출력하지 않습니다), wrapper 파일 자체는 직접 지워야 합니다.
- `/media:config display.statusline off`는 즉시 반영됩니다. 끄는 순간
  캐시된 줄이 삭제되므로 statusline을 재시작할 필요가 없습니다.
