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

## 켜기

Claude Code 안에서:

```
/media:config display.statusline on
```

설정은 이게 전부입니다. 켜기 전에 재생 정보를 실제로 읽을 수 있는지 먼저
검증하고(거부되면 `/media:doctor`를 실행해 보세요), 이어서 세그먼트를
Claude Code에 스스로 배선합니다:

1. `~/.claude/settings.json`의 현재 `"statusLine"` 값을
   `~/.claude/statusline-media.backup.json`에 백업합니다(원래 없었다면
   `null`).
2. `~/.claude/statusline-media.sh`에 wrapper 스크립트를 생성합니다. 기존
   statusline 명령을 먼저 실행하고, 그 뒤에 재생 정보 줄을 덧붙입니다.
3. `settings.json`의 `statusLine`이 wrapper를 가리키게 합니다. 기존 항목의
   다른 키(예: `padding`)는 모두 보존되고, `refreshInterval`을 직접 설정해
   두지 않았다면 `refreshInterval: 1`이 추가됩니다 — statusline은 원래 대화
   이벤트가 있을 때만 갱신되는데, 이 1초 주기 재실행이 있어야 가만히 있는
   동안에도 경과 시간과 진행 바가 움직입니다. (다시 그리는 횟수를 줄이고
   싶다면 `settings.json`에서 값을 올리거나 빼세요. 다시 그릴 때마다 기존
   statusline 명령도 함께 실행됩니다.)

세그먼트는 다음 statusline 틱에 바로 나타납니다 — 재시작도, 수동 단계도
없습니다. `/media:statusline`에서 배치를 저장해도 같은 방식으로 켜지고
배선됩니다.

## 설계상 보장되는 것 (안심해도 되는 이유)

1. 기존 statusline 명령은 **대체되지 않습니다**. wrapper가 기존 명령을 원래
   모습 그대로 먼저 실행하고, 그 출력은 **한 바이트도 바뀌지 않고** 그대로
   통과합니다. 재생 정보는 언제나 **별도의 줄로만 덧붙습니다**.
2. `display.statusline`이 꺼져 있으면(기본값) 세그먼트는 아무것도 출력하지
   않습니다. 빈 줄조차 없습니다. Claude Code가 없는 줄을 접어 주기 때문에
   statusline은 이전과 똑같이 보입니다. (`off`는 세그먼트를 즉시 숨기되
   배선은 남겨 두므로 다시 켜는 것도 즉시입니다.)
3. `settings.json`에서 건드리는 키는 정확히 하나 — `statusLine` — 이며,
   반드시 이전 값을 `statusline-media.backup.json`에 저장한 뒤에만
   수정합니다. 쓰기는 원자적이고, 심링크를 따라가며(dotfile 구성도
   안전합니다), 다른 설정 키는 전혀 손대지 않습니다.
4. **플러그인을 삭제하면 모든 것이 저절로 원복됩니다.** Claude Code에는
   플러그인이 쓸 수 있는 uninstall 훅이 없기 때문에, wrapper가 스스로
   치유하도록 만들었습니다: 매 틱마다 설치된 플러그인 목록을 확인하고,
   플러그인이 사라졌으면 백업해 둔 `statusLine`을 `settings.json`에
   복원한 뒤 자기 자신과 백업 파일을 삭제합니다. 아무것도 남지 않습니다 —
   삭제 후 1초 안에 statusline이 원래 모습 그대로 돌아옵니다.
5. 플러그인을 **비활성화**만 해 두면 wrapper는 아무것도 덧붙이지 않고
   기다립니다 — 기존 statusline은 평소대로 돌고, 배선은 다시 켤 때를 위해
   남아 있습니다.
6. **직접 손으로** 배선한 statusline(아래 레시피, 또는 세그먼트를 이미
   실행하는 어떤 명령이든)은 감지해서 설치·해제 어느 쪽에서도 절대
   건드리지 않습니다.

플러그인을 삭제하지 않고 배선만 해제하려면 — 백업을 복원하고 wrapper와
백업 파일을 지우며 `display.statusline`도 꺼 줍니다:

```
media.sh statusline uninstall     # 또는 그냥 "statusline 배선 해제해줘"라고 말하세요
```

`media.sh statusline status`는 현재 배선 상태(`managed`, `manual`,
`none`)를 알려 주고, `/media:doctor` 리포트에도 포함됩니다.

## 항목 배치하기

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
코드를 렌더링하고, wrapper는 이를 손대지 않고 그대로 넘깁니다:

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

진행 바의 문자는 `style.progressbar.style`이 정합니다:

| 프리셋 | 모양 | |
|---|---|---|
| `line`(기본값) | `━━━━━━────` | |
| `blocks` | `██████░░░░` | |
| `smooth` | `█████▋░░░░` | 경계 칸이 ⅛ 단위 부분 블록 |
| `knob` | `━━━━━●────` | 슬라이더 노브가 채움 끝을 표시 |
| `wave` | `▂▄▆▄▂▄▁▁▁▁` | 물결 — 재생 중 흘러감 |
| `pulse` | `▂▂█▁▄▂▁▁▁▁` | 심전도 박동 — 재생 중 흘러감 |
| `eq` | `▂▇▃█▅▆▁▁▁▁` | 이퀄라이저 — 재생 중 흘러감 |
| `notes` | `♪♫♪♫♪♫····` | 음표 — 재생 중 행진 |
| `braille` | `⣿⣿⣿⣿⣿⣿⣀⣀⣀⣀` | |
| `chevron` | `▸▸▸▸▸▸▹▹▹▹` | |
| `tape` | `▰▰▰▰▰▰▱▱▱▱` | |
| `cassette` | `▮▮▮▮▮▮▯▯▯▯` | |
| `retro` | `======----` | 순수 ASCII |
| `dots` | `●●●●●●○○○○` | |

"채움 + 빈칸"을 뜻하는 아무 두 글자도 됩니다(`"#-"` → `######----`).
움직이는 프리셋은 재생 중에는 파형이 매초 빈 쪽으로 흘러가고, 일시정지하면
멈춥니다. `/media:now` 응답의 진행 바도 같은 문자로 그려지기 때문에 두
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

## 수동 설정 (커스텀 statusline)

배선을 직접 관리하고 싶다면 — 예컨대 세그먼트를 별도 줄로 덧붙이는 대신
자기 statusline 스크립트 *안에* 넣고 싶다면? 명령을 **먼저** 구성해 두고 그
다음에 세그먼트를 켜세요. 자동 배선은 세그먼트를 이미 실행하는
`statusLine` 명령(`statusline-media.sh` 또는 `media.sh … statusline`이
들어 있는 명령)을 인식해서 완전히 그대로 두고, 켜기는 표시 토글만
바꿉니다.

출발점으로 쓸 만한 범용 wrapper — `~/.claude/statusline-media.sh`로
저장하고 실행 권한을 주세요(`chmod +x ~/.claude/statusline-media.sh`):

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

(`refreshInterval: 1`은 가만히 있는 동안에도 시간과 바가 움직이게
해 줍니다 — 위의 "켜기" 참고.) 체크아웃한 리포에서 개발
중이라면(`claude --plugin-dir`) `MEDIA_DIR` 블록을 리포 경로로 바꾸면
됩니다:
`np="$(/path/to/claude-media-control/scripts/media.sh statusline 2>/dev/null)"`

## 관리 팁

- **자동 배선(managed)**: wrapper는 생성된 파일이므로 직접 고치지 마세요.
  플러그인 업데이트 시(세션 시작 warm-up) 그리고 `media.sh statusline
  install`을 다시 실행할 때 새로 생성됩니다. `media.sh statusline
  uninstall`은 배선을 해제하고 이전 statusline을 복원하며, 플러그인을
  삭제하면 다음 statusline 틱에 같은 일이 자동으로 일어납니다.
- **수동 배선(manual)**: 파일들은 사용자의 것이고 플러그인은 절대 건드리지
  않습니다. 나중에 statusline 구성을 바꾸면 `EXISTING` 줄도 같이 고쳐
  주세요. 되돌리려면 `settings.json`의 `"statusLine"` 값을 원래대로
  복원하고 wrapper를 지우면 됩니다. 플러그인만 삭제해도 세그먼트는 알아서
  조용해지지만(플러그인 설정이 데이터 디렉토리와 함께 사라집니다), 파일
  자체는 직접 지워야 합니다.
- `/media:config display.statusline off`는 즉시 반영됩니다. 끄는 순간
  캐시된 줄이 삭제되므로 statusline을 재시작할 필요가 없습니다.
