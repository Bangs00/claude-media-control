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

### 항목 배치하기

`/media:statusline`을 실행하면 프리셋(Standard / Everything / Compact)을
미리보기로 직접 보면서 고를 수 있고, 한 줄로 붙일지 그룹마다 줄을 나눌지도
그 자리에서 정합니다. `Custom…`을 고르면 표시할 항목과 맨 앞에 올 항목을
하나씩 골라 나만의 배치를 만들 수 있습니다. 간단한 프리셋 picker는
`/media:config` 안에서도 열립니다:

- **항목** (원하는 대로 조합, **원하는 순서로**): `track`(▶︎ 제목 —
  아티스트), `app`(재생 중인 앱, 예: `(Spotify)`),
  `progressbar`(`██████░░░░`), `time`(`2:13/4:24`), `output`(🔊 현재 오디오
  출력 장치). 기본 구성은 `track app progressbar time`입니다.
- **순서**: 항목은 저장한 순서 그대로 그려집니다. "시간을 맨 앞에",
  "출력 장치를 앞으로"라고 말해도 되고, 직접 지정할 수도 있습니다:
  `/media:config statusline.fields "time,progressbar,track,app"`.
- **배치**: 한 줄로 붙이거나, 그룹마다 줄을 나누거나(`statusline.multiline`).
  `app`은 track 그룹에 붙고, `progressbar`와 `time`은 순서상 이웃해 있을 때
  한 그룹(여러 줄 배치에서는 한 줄)을 이룹니다. track과 `output`도
  마찬가지라서, 출력 장치를 track 바로 뒤에 두면 줄을 나눠도 track과 같은
  줄에 남습니다.

모든 항목을 한 줄로:

```
▶︎ Karma Police — Radiohead (Spotify)  ██████░░░░  2:13/4:24  🔊 AirPods Pro
```

여러 줄로(`statusline.multiline on`):

```
▶︎ Karma Police — Radiohead (Spotify)
██████░░░░  2:13/4:24
🔊 AirPods Pro
```

출력 장치를 track 줄에
(`statusline.fields "track,app,output,progressbar,time"`):

```
▶︎ Karma Police — Radiohead (Spotify)  🔊 AirPods Pro
██████░░░░  2:13/4:24
```

시간을 앞으로(`statusline.fields "time,progressbar,track,app"`):

```
2:13/4:24  ██████░░░░  ▶︎ Karma Police — Radiohead (Spotify)
```

`output` 항목은 네이티브 helper가 필요합니다(세그먼트가 원래 하던 조회에
함께 실려 오기 때문에 추가 비용은 없습니다). 장치 전환은 `/media:output`으로
하면 되고, 세그먼트는 다음 갱신 때 바로 반영됩니다.

### 긴 제목: marquee 스크롤

30칸(터미널 셀)보다 긴 제목은 고정된 30칸 창 안에서 1초에 한 글자씩
흘러갑니다(아래의 1초 갱신 주기와 맞물려, 다시 그려질 때마다 한 칸씩
전진합니다):

```
▶︎ ing Willow (10 Minute Version)  — Taylor Swift (Music)
```

한글·한자·가나 문자는 두 칸으로 계산하므로 CJK 제목에서도 창 너비가
일정하게 유지됩니다. 아무리 길어도 제목 전체를 보고 싶다면 끄면 됩니다:

```
/media:config statusline.marquee off
```

### 색상

세그먼트는 기본으로 스타일이 입혀져 나옵니다. Claude Code statusline은 ANSI
코드를 렌더링하고, 아래 wrapper는 이를 손대지 않고 그대로 넘깁니다:

- 아이콘과 진행 바의 채워진 부분은 재생 상태를 따라 색이 바뀝니다
  (재생 중 green, 일시정지 yellow)
- **굵은** 제목과 경과 시간(계속 움직이는 부분이라 또렷하게 보입니다),
  *기울임꼴* 아티스트, 흐리게 표시되는 전체 시간·빈 칸·앱 이름·출력 장치

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
