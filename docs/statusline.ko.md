# statusline에 재생 중인 곡 띄우기

[English](statusline.md) | **한국어** | [日本語](statusline.ja.md) | [简体中文](statusline.zh-CN.md)

Claude Code statusline에 현재 곡을 한 줄 추가해 보여줍니다:

```
[기존 statusline은 그대로]
▶︎ Karma Police — Radiohead  ██████░░░░  2:13/4:24
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

### 보여줄 항목 고르기

`/media:statusline`을 실행하면 어떤 항목을 어떻게 배치할지 고를 수 있습니다:

- **항목** (원하는 대로 조합): `track`(▶︎ 제목 — 아티스트),
  `progressbar`(`██████░░░░`), `time`(`2:13/4:24`), `spectrum`(실시간
  주파수 막대). 전부 고르면 다 나옵니다.
- **배치**: 한 줄로 붙이거나, 그룹마다 줄을 나누거나(`statusline.multiline`).

모든 항목을 한 줄로:

```
▶︎ Karma Police — Radiohead  ██████░░░░  2:13/4:24  ▂▄▆█▇▅▃▂
```

여러 줄로(`statusline.multiline on`):

```
▶︎ Karma Police — Radiohead
██████░░░░  2:13/4:24
▂▄▆█▇▅▃▂
```

`spectrum` 항목은 선택 기능이라 `display.spectrum on`과 시스템 오디오 녹음
권한이 필요합니다(`/media:spectrum` 참고). 갱신할 때마다 약 0.5초씩 소리를
캡처하기 때문에 다른 항목보다 무겁습니다. statusline을 최대한 가볍게 쓰고
싶다면 빼는 편이 낫습니다.

### 색상

세그먼트는 기본으로 스타일이 입혀져 나옵니다. Claude Code statusline은 ANSI
코드를 렌더링하고, 아래 wrapper는 이를 손대지 않고 그대로 넘깁니다:

- 아이콘과 진행 바의 채워진 부분은 재생 상태를 따라 색이 바뀝니다
  (재생 중 green, 일시정지 yellow)
- **굵은** 제목, *기울임꼴* 아티스트, 흐리게 표시되는 시간과 빈 칸
- 스펙트럼 막대는 `spectrum.style` 설정대로 색이 입혀집니다:
  - `solid` (기본) — 모든 막대를 한 가지 색으로. 색은 `spectrum.color`에서
    고릅니다 (`red green yellow blue magenta cyan white`, 기본 `cyan`)
  - `rainbow` — 막대 위치에 따라 앞에서 뒤로 색이 고정 순환합니다(음량과는
    무관). 1초에 한 칸씩 흘러가고, `spectrum.color`는 무시됩니다

```
/media:config spectrum.style rainbow
/media:config spectrum.color magenta
```

표준 16색 SGR 코드만 쓰기 때문에 실제 색은 터미널의 팔레트를 따릅니다.
색 없이 쓰고 싶다면 `/media:config statusline.color off`를 실행하세요.
`NO_COLOR` 환경 변수도 지원합니다.

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
