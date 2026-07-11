# statusline에 재생 중인 곡 띄우기

[English](statusline.md) | **한국어** | [日本語](statusline.ja.md) | [简体中文](statusline.zh-CN.md)

Claude Code statusline에 현재 곡이 한 줄 추가됩니다:

```
[기존 statusline은 그대로]
▶︎ Karma Police — Radiohead (Spotify)  ━━━━━━━━━━━━────────  2:13/4:24
```

세그먼트는 1초 TTL 캐시에서 50ms도 안 걸려 응답하므로 statusline이
느려질 일은 없습니다. 실제 재생 정보 조회는 초당 최대 한 번 — 시간과
바가 1초에 한 번씩 움직이는 것도 이 주기 덕분입니다.

## 켜기

```
/media:config display.statusline on
```

설정은 이게 전부입니다 — 재시작도, 수동 단계도 없습니다.
(`/media:statusline`에서 배치를 저장해도 같은 방식으로 켜집니다.) 켜기
전에 재생 정보를 실제로 읽을 수 있는지 먼저 검증하고(거부되면
`/media:doctor`), 이어서 세그먼트를 스스로 배선합니다:

1. `~/.claude/settings.json`의 현재 `"statusLine"` 값을
   `~/.claude/statusline-media.backup.json`에 백업합니다(없었다면 `null`).
2. `~/.claude/statusline-media.sh`에 wrapper를 생성합니다. 기존 statusline
   명령을 먼저 실행하고, 그 뒤에 재생 정보 줄을 덧붙입니다.
3. `settings.json`이 wrapper를 가리키게 합니다. 기존 항목의 다른 키(예:
   `padding`)는 모두 보존되고, 직접 설정해 두지 않았다면
   `refreshInterval: 1`이 추가됩니다 — 이 1초 주기 재실행이 있어야 가만히
   있는 동안에도 시간과 바가 움직입니다. (다시 그리는 횟수를 줄이려면
   값을 올리거나 빼세요. 다시 그릴 때마다 기존 statusline 명령도 함께
   실행됩니다.)

## 클릭으로 조작하기

하이퍼링크를 지원하는 터미널에서는 세그먼트가 **⌘+클릭**에 반응합니다:

| 대상 | ⌘+클릭 동작 |
| --- | --- |
| `▶︎` / `⏸` 아이콘 | 재생/일시정지 토글 |
| 제목 — 가수, `(앱)` | 재생 중인 미디어로 이동: 재생 중인 브라우저 탭(Safari, Chrome, Edge, Brave, Vivaldi, Opera) 또는 Music의 현재 트랙 — 그 외 앱은 앱만 앞으로 |
| 진행 바 | seek — 모든 칸이 각자의 위치로 점프 (기본 20칸이면 2.5%, 7.5%, … 97.5%; 바가 길수록 더 촘촘하게) |

- **지원 터미널**: iTerm2, Ghostty, WezTerm, Kitty, VS Code, Alacritty
  0.11+ (tmux 3.4+는 링크를 통과시킵니다). 하이퍼링크를 모르는 터미널은
  그냥 일반 세그먼트로 보입니다.
- 클릭 결과는 다음 틱(1초 이내)에 반영됩니다: 아이콘이 바뀌고 바가
  점프합니다.
- 스위치: `/media:config statusline.links off`는 링크 없는 일반
  세그먼트로 되돌립니다. 다시 켜면 핸들러 앱을 재생성하는데, 빌드가
  실패하면 거부됩니다(exit 3) — 아무도 받지 않는 링크는 없느니만
  못하니까요.
- 첫 탭 이동 시 자동화 허용(`ClaudeMediaClick.app`)을 한 번 묻습니다 —
  거부해도 조용히 앱 활성화까지만 동작합니다.

<details>
<summary>클릭이 동작하는 원리 (그리고 안전한 이유)</summary>

클릭 가능한 부분은 로컬 `claude-media://` URL 스킴을 가리키는 OSC 8
하이퍼링크입니다. statusline을 켜면 작은 핸들러 앱(`ClaudeMediaClick.app`
— macOS 기본 도구 `osacompile`로 플러그인 데이터 디렉터리에 생성, 서드파티
코드 없음)이 만들어져 LaunchServices에 등록됩니다. 클릭하면 `media.sh
open-url`이 실행되는데, 받아 주는 동작은 정확히 세 가지 — toggle,
activate, 퍼센트 seek — 뿐이고 그 외는 전부 거부합니다. URL 스킴은 원래
어떤 앱이든 열 수 있는 시스템 전역 통로라서, 표면을 이렇게 좁힌 것
자체가 핵심입니다: 재생/일시정지, 앱 앞으로, seek — 최악이라도 성가심
수준이고 키보드 미디어 키와 같은 등급입니다.

브라우저 재생은 웹 콘텐츠 헬퍼 프로세스를 소유 앱으로 해석해
활성화하고(예: `com.openai.atlas.web` → ChatGPT Atlas), 앱이 스크립팅을
지원하면 미디어 자체에 내려앉습니다: 트랙 제목과 일치하는 창+탭을
선택하거나 Music의 현재 트랙을 표시합니다. 스크립팅 인터페이스가 없는
앱(예: ChatGPT Atlas, Spotify)은 앞으로 나오는 데서 멈춥니다. 플러그인을
삭제하면(또는 `media.sh statusline uninstall`) 핸들러 앱도 등록 해제되고
삭제됩니다. 상태는 `/media:doctor`가 보고합니다(`Click links`).

</details>

## 업데이트는 사용 중인 탭을 따라갑니다

Claude Code 세션을 여러 개 열어 두면 세그먼트는 **실제로 사용 중인
세션에서만 업데이트됩니다** — 타이핑, 스크롤, 그 탭으로 전환하는 것까지
전부 사용으로 칩니다. 다른 세션은 마지막 줄을 얼린 채 유지하고(곡 정보는
계속 보이고 바와 시간만 멈춥니다), 돌아오면 한두 틱 안에 따라잡습니다.
원래 쓰던 statusline은 모든 세션에서 계속 살아 움직입니다 — 게이트는
플러그인 줄에만 걸립니다. 설정할 것은 없습니다.

모든 세션에서 움직이는 쪽이 좋다면:

```
/media:config statusline.activetab off
```

<details>
<summary>게이트가 동작하는 원리</summary>

statusline 명령은 제어 tty 없이 실행되므로, 세그먼트는 프로세스 부모
체인을 따라 세션의 터미널을 쥔 Claude Code 프로세스를 찾아내고, 터미널들의
마지막 입력 시각(`w`가 IDLE로 보여주는 그 atime 신호)을 플러그인 데이터
디렉터리의 작은 상태 파일로 비교합니다(`statusline.tty` — 내용은 현재
보유자의 디바이스, mtime은 보유자의 heartbeat라서 세션이 닫히면 몇 초 안에
자리를 내놓습니다). 살아 있는 렌더는 매번 터미널별
스냅샷(`statusline.frozen.<tty>`)도 남기는데, 비활성 세션이 다시 찍는 줄이
바로 이것입니다. 자기 tty가 없는 세션(VS Code, 데스크톱 앱, headless)은
순위를 매길 수 없어 경쟁 없이 항상 살아 있는 렌더를 하고, 게이트 내부의
모든 실패는 fail-open입니다 — 고장 나면 얼리는 쪽이 아니라 살아 있는
쪽으로 동작합니다.

</details>

## 항목 배치하기

`/media:statusline`이 세그먼트의 모습을 정하는 허브입니다 — 탭 세 개:
**Items**(켜고 끄기), **Layout**(프리셋 또는 숫자 패턴),
**Style**([스타일 갤러리](styles.ko.md) 참고). 패턴의 범례:

| # | 항목 | 표시 예 |
| --- | --- | --- |
| 1 | `track` | `▶︎ Karma Police — Radiohead` |
| 2 | `app` | `(Spotify)` |
| 3 | `volume` | `🔉 ▄ 45%` — 음소거면 `🔇` |
| 4 | `progressbar` | `━━━━━━━━━━━━────────` |
| 5 | `time` | `2:13/4:24` |
| 6 | `output` | `🎧 AirPods Pro` — 아이콘은 장치 종류를 따름 |

숫자 순서가 곧 표시 순서고, `/`는 새 줄을 시작하며, 뺀 숫자의 항목은
표시되지 않습니다. 기본 구성은 `track app progressbar time`이고, 목록을
직접 지정할 수도 있습니다:
`/media:config statusline.fields "time,progressbar,track,app"`.

Standard — 모든 항목을 한 줄로(`123456`):

```
▶︎ Karma Police — Radiohead (Spotify)  🔉 ▄ 45%  ━━━━━━━━━━━━────────  2:13/4:24  🎧 AirPods Pro
```

Stacked — 2줄(`123/456`):

```
▶︎ Karma Police — Radiohead (Spotify)  🔉 ▄ 45%
━━━━━━━━━━━━────────  2:13/4:24  🎧 AirPods Pro
```

출력 장치를 track 줄에, 볼륨은 빼고(`126/45`):

```
▶︎ Karma Police — Radiohead (Spotify)  🎧 AirPods Pro
━━━━━━━━━━━━────────  2:13/4:24
```

배치 규칙:

- **목록에 `/`가 있으면** (명시 배치): 각 줄에는 거기에 둔 항목만 그
  순서대로 나옵니다. 보여줄 것이 없는 줄은 통째로 사라집니다 — 빈 줄은
  생기지 않습니다.
- **`/`가 없으면** (그룹 배치): 한 줄로 붙이거나, `statusline.multiline
  on`이면 그룹마다 줄을 나눕니다. 그룹 규칙: `app`은 track에 붙고, 이웃한
  `progressbar`+`time`은 한 쌍이 되고, `output`/`volume`은 이웃한 track
  그룹에 합류합니다(서로 이웃하면 둘이 한 쌍).
- `output`과 `volume`은 네이티브 helper가 필요합니다. 세그먼트가 원래
  하던 조회에 실려 오므로 추가 비용은 없습니다.

## 꾸미기

세그먼트는 기본으로 스타일이 입혀져 나옵니다: 재생 상태에 따른
green/yellow 강조색, **굵은** 제목과 경과 시간, *기울임꼴* 아티스트,
흐리게 처리된 나머지 — 표준 16색 SGR만 쓰므로 실제 색감은 터미널 팔레트를
따릅니다.

모든 부분을 하나하나 따로 꾸밀 수 있습니다 — 색, 굵게/기울임, 14가지 진행
바 문자, 바 길이(1–60칸, 기본 20), 볼륨 바 모양, 아이콘, 그리고 `off`로
숨기기까지. **전체 카탈로그와 예시, 레시피:
[docs/styles.ko.md](styles.ko.md)**

```
/media:config statusline.color off     # 일반 텍스트로 (NO_COLOR도 지원)
/media:config statusline.marquee off   # 긴 제목 스크롤 끄기
```

30칸(터미널 셀)보다 긴 제목은 고정 창 안에서 1초에 한 글자씩
흘러갑니다(한글·한자·가나는 두 칸으로 계산해 창 너비가 일정합니다).

## 토글 한눈에 보기

| 키 (`/media:config …`) | 기본값 | 역할 |
| --- | --- | --- |
| `display.statusline` | `off` | 세그먼트 표시 (켜면 배선까지 자동) |
| `statusline.fields` | `track,app,progressbar,time` | 항목, 순서, `/` 줄바꿈 |
| `statusline.multiline` | `off` | 그룹 배치에서 그룹마다 한 줄 |
| `statusline.color` | `on` | ANSI 스타일 (`NO_COLOR`가 우선) |
| `statusline.marquee` | `on` | 30칸 넘는 제목 스크롤 |
| `statusline.links` | `on` | ⌘+클릭 동작 |
| `statusline.activetab` | `on` | 사용 중인 탭에서만 업데이트 |
| `statusline reset` | — | 기본 모습으로 (배치·줄·색·marquee·스타일) |

## 수동 설정 (커스텀 statusline)

배선을 직접 관리하고 싶다면 — 예컨대 세그먼트를 별도 줄이 아니라 자기
statusline 스크립트 *안에* 넣고 싶다면? 명령을 **먼저** 구성해 두고 그
다음에 켜세요. 자동 배선은 세그먼트를 이미 실행하는 `statusLine`
명령(`statusline-media.sh` 또는 `media.sh … statusline`이 들어 있는
명령)을 인식해서 그대로 두고, 켜기는 표시 토글만 바꿉니다.

출발점으로 쓸 만한 범용 wrapper — `~/.claude/statusline-media.sh`로
저장하고 `chmod +x`:

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

그다음 `~/.claude/settings.json`이 이 파일을 가리키게 직접 수정합니다:

```json
{
  "statusLine": {
    "type": "command",
    "command": "\"$HOME/.claude/statusline-media.sh\"",
    "refreshInterval": 1
  }
}
```

체크아웃한 리포에서 개발 중이라면(`claude --plugin-dir`) `MEDIA_DIR`
블록을 리포 경로로 바꾸면 됩니다:
`np="$(/path/to/claude-media-control/scripts/media.sh statusline 2>/dev/null)"`

## 설계상 보장되는 것 (안심해도 되는 이유)

1. 기존 statusline은 **대체되지 않습니다** — wrapper가 먼저 실행하고 그
   출력은 한 바이트도 바뀌지 않고 통과하며, 재생 정보는 언제나 별도의
   줄로만 덧붙습니다.
2. 꺼져 있으면(기본값) 아무것도 출력하지 않습니다 — 빈 줄조차 없습니다.
   Claude Code가 없는 줄을 접어 주므로 statusline은 이전과 똑같이
   보입니다.
3. `settings.json`에서 건드리는 키는 정확히 하나 — `statusLine` — 이며,
   반드시 이전 값을 백업한 뒤에만 수정합니다. 쓰기는 원자적이고, 심링크를
   따라가며(dotfile 구성도 안전), 다른 키는 전혀 손대지 않습니다.
4. **플러그인을 삭제하면 모든 것이 저절로 원복됩니다.** Claude Code에는
   uninstall 훅이 없어서 wrapper가 스스로 치유합니다: 플러그인이 사라지면
   백업해 둔 `statusLine`을 복원하고 자기 자신과 백업 파일을 삭제하며,
   클릭 핸들러 앱도 함께 제거합니다 — 삭제 후 1초 안에.
5. 플러그인을 **비활성화**만 해 두면 wrapper는 아무것도 덧붙이지 않고
   기다립니다 — 기존 statusline은 평소대로 돕니다.
6. **직접 손으로** 배선한 statusline은 감지해서 설치·해제 어느 쪽에서도
   절대 건드리지 않습니다.

## 배선 명령

```
media.sh statusline status      # managed | manual | none (/media:doctor에도 표시)
media.sh statusline uninstall   # 플러그인은 두고 배선만 해제:
                                # 백업 복원, wrapper + 백업 삭제,
                                # display.statusline off
```

참고:

- **자동 배선(managed)**: wrapper는 생성된 파일이므로 직접 고치지 마세요.
  플러그인 업데이트 시, 그리고 `media.sh statusline install`을 다시 실행할
  때 새로 생성됩니다.
- **수동 배선(manual)**: 파일들은 사용자의 것이고 플러그인은 절대 건드리지
  않습니다. statusline 구성을 바꾸면 `EXISTING` 줄도 같이 고쳐 주세요.
  플러그인만 삭제해도 세그먼트는 알아서 조용해지지만, wrapper 삭제와
  `"statusLine"` 복원은 직접 해 주세요.
- `/media:config display.statusline off`는 즉시 반영됩니다 — 끄는 순간
  캐시된 줄이 삭제되고, 배선은 남아 있어 다시 켜는 것도 즉시입니다.
