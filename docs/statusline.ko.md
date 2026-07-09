# statusline에 now-playing 표시

[English](statusline.md) | **한국어** | [日本語](statusline.ja.md) | [简体中文](statusline.zh-CN.md)

Claude Code statusline에 현재 트랙을 추가 줄로 표시:

```
[기존 statusline, 그대로 유지]
▶︎ Karma Police — Radiohead  ██████░░░░  2:13/4:24
```

- 세그먼트는 `media.sh statusline`이 생성하며, 소형 TTL 캐시(기본 1초)에서 50ms 이내에 응답 — statusline을 절대 느리게 만들지 않음
- 실제 now-playing 읽기는 TTL 윈도우당 최대 1회 실행되므로, statusline이 다시 그려질 때 경과 시간과 progress bar가 약 1초 간격으로 갱신됨

## 설계 보장 (안전하게 추가할 수 있는 이유)

1. 기존 statusline 명령은 **교체되지 않음** — wrapper가 기존 명령을 원래 그대로 먼저 실행
2. 기존 출력은 **바이트 단위 그대로** 통과
3. now-playing은 항상 **별도 줄로만 추가**됨
4. `display.statusline`이 off(기본값)면 세그먼트 명령은 아무것도 출력하지 않음 — 빈 줄조차 없음. Claude Code가 누락된 줄을 접어주므로 statusline은 이전과 완전히 동일하게 표시됨

플러그인은 `settings.json`을 대신 수정하지 않음. 아래 모든 단계는 수동이며 되돌릴 수 있는 편집임.

## 1단계 — 세그먼트 활성화

Claude Code 안에서:

```
/media:config display.statusline on
```

(활성화 시 동작하는 now-playing 읽기 경로를 먼저 검증하며, 거부되는 경우 `/media:doctor` 실행 필요.)

### 세그먼트 표시 항목 선택

`/media:statusline` 실행으로 표시 항목과 레이아웃 선택:

- **항목** (자유 조합): `track`(▶︎ 제목 — 아티스트), `progressbar`(`██████░░░░`), `time`(`2:13/4:24`), `spectrum`(실시간 주파수 바). 전체 선택 시 모두 표시
- **레이아웃**: 한 줄, 또는 그룹별 별도 줄(`statusline.multiline`)

전체 항목 한 줄 표시:

```
▶︎ Karma Police — Radiohead  ██████░░░░  2:13/4:24  ▂▄▆█▇▅▃▂
```

여러 줄 표시(`statusline.multiline on`):

```
▶︎ Karma Police — Radiohead
██████░░░░  2:13/4:24
▂▄▆█▇▅▃▂
```

`spectrum` 항목은 opt-in이며 `display.spectrum on`과 시스템 오디오 녹음 권한 필요(`/media:spectrum` 참고). 갱신마다 ~0.5초의 오디오를 캡처하므로 다른 항목보다 무거움 — 가장 가벼운 statusline을 원하면 제외 권장.

### 색상

세그먼트는 기본으로 스타일 적용 상태로 출력됨 — Claude Code statusline은 ANSI 코드를 렌더링하며, 아래 wrapper는 이를 그대로 통과시킴:

- 아이콘과 progress bar의 채워진 부분은 재생 상태를 따름 (재생 중 green, 일시정지 yellow)
- **bold** 제목, *italic* 아티스트, 흐리게 처리된 시간·빈 바 셀
- 스펙트럼 바는 `spectrum.style`에 따라 색조 적용:
  - `solid` (기본) — 모든 바를 한 색으로, `spectrum.color`로 선택 (`red green yellow blue magenta cyan white`, 기본 `cyan`)
  - `rainbow` — 바 위치 기반의 고정 front-to-back 색상 순환(음량 기반 아님), 초당 한 스텝씩 이동. `spectrum.color`는 무시됨

```
/media:config spectrum.style rainbow
/media:config spectrum.color magenta
```

표준 16색 SGR 코드만 사용하므로 모든 색은 터미널 자체 팔레트를 따름. 일반 텍스트 선호 시 `/media:config statusline.color off` 실행 — `NO_COLOR` 환경 변수도 지원.

## 2단계 — wrapper 스크립트 생성

`~/.claude/statusline-media.sh`로 저장 후 실행 권한 부여
(`chmod +x ~/.claude/statusline-media.sh`):

```bash
#!/bin/bash
# statusline-media.sh — 기존 statusline(그대로) + now-playing 줄.
input=$(cat)

# ── 1. 기존 statusLine 명령을 따옴표 사이에 그대로 붙여넣기.
#       settings.json의 "statusLine" 아래 "command" 값에서 가져올 것.
#       기존 statusline이 없었다면 EXISTING을 비워둘 것.
EXISTING=''
if [ -n "$EXISTING" ]; then
  printf '%s' "$input" | bash -c "$EXISTING"
fi

# ── 2. now-playing (off / 재생 없음 / 플러그인 없음이면 빈 출력).
#       실행 시점에 설치된 최신 플러그인 버전을 찾으므로
#       wrapper는 플러그인 업데이트 후에도 계속 동작함.
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

checkout에서 개발 중(`claude --plugin-dir`)이라면 `MEDIA_DIR` 블록을 리포 경로로 교체: `np="$(/path/to/claude-media-control/scripts/media.sh statusline 2>/dev/null)"`.

## 3단계 — settings.json이 wrapper를 가리키도록 설정

`~/.claude/settings.json`에서:

```json
{
  "statusLine": {
    "type": "command",
    "command": "\"$HOME/.claude/statusline-media.sh\""
  }
}
```

**라이브한 statusline을 원하면 권장:** `"command"` 옆에 `"refreshInterval": 1` 추가. statusline은 기본적으로 대화 이벤트 시에만 갱신되므로 유휴 상태에서는 경과 시간과 progress bar가 멈춤. `refreshInterval`은 명령을 주기적으로 재실행하며, `1`(최솟값)은 세그먼트의 1초 캐시와 맞물려 시간과 바가 매초 갱신됨. 다시 그리기 횟수를 줄이고 싶으면 제거하거나 값을 올릴 것(다시 그릴 때마다 기존 statusline 명령도 재실행됨).

## 유지 관리 참고

- wrapper는 이전 statusline 명령의 **복사본**을 `EXISTING`에 보관. 이후 statusline 구성을 바꾸면 해당 줄도 함께 갱신 필요
- 전부 되돌리기: `settings.json`의 이전 `"statusLine"` 값 복원 후 `~/.claude/statusline-media.sh` 삭제. 플러그인 제거만으로도 세그먼트는 자동으로 사라짐(플러그인이 없으면 wrapper가 아무것도 출력하지 않음). 단 wrapper 파일 자체는 직접 삭제 필요
- 세그먼트는 `/media:config display.statusline off`를 즉시 반영 — 비활성화 시 캐시된 줄이 삭제되며 statusline 재시작 불필요
