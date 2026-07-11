# claude-media-control

[![CI](https://github.com/Bangs00/claude-media-control/actions/workflows/ci.yml/badge.svg)](https://github.com/Bangs00/claude-media-control/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![macOS](https://img.shields.io/badge/platform-macOS-black)
![Claude Code plugin](https://img.shields.io/badge/Claude%20Code-plugin-d97757)
![Zero dependencies](https://img.shields.io/badge/dependencies-zero-brightgreen)

[English](README.md) | **한국어** | [日本語](README.ja.md) | [简体中文](README.zh-CN.md)

**지금 재생 중인 곡이 Claude Code statusline에 실시간으로** — 1초마다
움직이고, ⌘+클릭으로 조작하고, 진행 바 문자 하나까지 원하는 대로 꾸밀 수
있습니다:

```
▶︎ Karma Police — Radiohead (Spotify)  🔉 ▄ 45%
━━━━━━━━━━━━────────  2:13/4:24  🎧 AirPods Pro
```

Mac에서 재생 중인 것이 무엇이든 — Spotify, Apple Music, 브라우저 탭,
VLC — 대화로도 조작할 수 있습니다: "지금 무슨 노래야?", "잠깐 멈춰줘",
"다음 곡", "에어팟으로 틀어줘". **macOS 시스템 전역 now-playing 서비스**와
직접 통신하므로 특정 앱에 묶이지 않고, OAuth도 API 키도 필요 없으며,
Homebrew로 설치할 것도 없습니다.

![claude-media-control 데모](docs/demo.ko.gif)

## 빠른 시작

Claude Code 안에서:

```
/plugin marketplace add Bangs00/claude-media-control
/plugin install media@claude-media-control
/media:config display.statusline on
```

마지막 줄이 statusline입니다 — 배선까지 자동으로 끝나고, 다음 틱에 바로
나타납니다. macOS 전용이며, 첫 media 명령 때 작은 native helper를 한 번만
빌드합니다(약 2초). 설치 확인은 `/media:doctor`(정상이면
`verdict: PRIMARY OK`).

## Statusline

아래 전부가 자동입니다 — 자세한 가이드는
[docs/statusline.ko.md](docs/statusline.ko.md):

- **안전한 배선.** 켜면 세그먼트가 기존 statusline 뒤에 별도 줄로
  덧붙습니다 — 기존 statusline은 한 바이트도 바뀌지 않고 그대로 돕니다.
  이전 `statusLine` 값은 백업해 두었다가 **플러그인을 삭제하면 자동으로
  복원됩니다**. 재시작도, 수동 단계도 없습니다.
- **⌘+클릭으로 조작** (iTerm2, Ghostty, WezTerm, Kitty, VS Code 등):
  ▶︎/⏸ 아이콘은 재생/일시정지, 제목은 재생 중인 브라우저 탭이나 Music
  트랙으로 이동, 진행 바는 셀 단위로 그 위치로 seek. 미지원 터미널에서는
  그냥 일반 세그먼트로 보입니다.
- **업데이트는 사용 중인 탭만.** 세션을 여러 개 열어 두면 실제로 쓰고
  있는 탭에서만 움직이고, 나머지는 마지막 줄을 얼린 채 있다가 돌아오는
  순간 따라잡습니다.
- **숫자 패턴으로 배치** — `/media:statusline`에서: 숫자가 항목이고 —
  1 곡 정보 · 2 앱 · 3 볼륨 · 4 바 · 5 시간 · 6 출력 장치 — `/`가
  줄바꿈이라, `123/456`이면 곡/앱/볼륨 위에 바/시간/출력이 쌓입니다.
- **부분별 스타일**: 재생/일시정지 강조색, 부분마다 굵게/기울임/색,
  진행 바 문자 14종(기본 `line` `━━──`부터 `smooth` 부분 블록, `knob`
  슬라이더 노브, 재생 중 흘러가는 `wave`/`pulse`/`eq`/`notes`까지), 바
  길이(1–60칸), 볼륨 바 모양, 아이콘 — 그리고 `off`로 어떤 부분이든
  숨기기. **전부 예시와 함께
  [스타일 갤러리](docs/styles.ko.md)에 있습니다.**

## 대화로 조작하기

자연어, slash command, 인터랙티브 메뉴 — 어느 쪽이든 됩니다:

| 이렇게 말하면 | …또는 이렇게 | 이런 일이 일어납니다 |
| --- | --- | --- |
| "지금 무슨 노래야?" | `/media:now` | 제목 / 아티스트 / 앱 + 진행 바 |
| "음악 꺼줘" | `/media:pause` · `/media:toggle` | 일시정지 / 재개 |
| "다음 곡 틀어줘" | `/media:next` · `/media:prev` | 다음 곡 / 이전 곡 |
| "1:30으로 넘겨줘" | `/media:seek 1:30` | 원하는 위치로 이동 |
| "앨범 커버 보여줘" | `/media:artwork` | 커버를 저장해서 표시 |
| "소리 좀 줄여줘" | `/media:volume 30` | 시스템 출력 볼륨 (0–100) |
| "아까 무슨 노래 나왔었지?" | `/media:history` | 최근 재생된 곡 목록 |
| "에어팟으로 틀어줘" | `/media:output airpods` | 출력 장치 확인 / 전환 |
| "리모컨 띄워줘" | `/media:menu` | 방향키 인터랙티브 컨트롤러 |
| "제목을 하늘색으로 해줘" | `/media:statusline` | statusline 배치 + 스타일 |
| "히스토리 꺼줘" | `/media:config` | 빠른 토글 + statusline 초기화 |
| — | `/media:doctor` | 빌드 / 권한 / fallback 진단 |

재생 히스토리는 **얹혀서** 기록됩니다 — 어차피 일어나는 조회(statusline
틱, 명령)에 편승하므로 폴링도 데몬도 없습니다. 로그는 최근 500곡까지
로컬에만 보관되고 컴퓨터 밖으로 나가지 않습니다(`/media:config
history.record off`로 중단, `/media:history clear`로 삭제). 출력 장치
목록과 전환은 공개 CoreAudio API를 쓰므로 별도 권한이 필요 없습니다.

## 동작 원리

macOS에는 다른 앱의 재생 정보를 읽는 공개 API가 없고, 비공개 `MediaRemote`
프레임워크는 15.4부터 Apple이 서명한 프로세스에만 응답합니다.
[ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter)와
같은 기법으로, 작은 Objective-C helper(`native/adapter.m`)를 Apple 플랫폼
바이너리인 `/usr/bin/perl`이 로드해 entitlement 검사를 통과합니다.
Command Line Tools가 없으면 컴파일이 필요 없는 `osascript`/JXA 읽기와
앱별 AppleScript 조작(Spotify / Apple Music)으로 대신합니다. 지금 어떤
모드인지는 `/media:doctor`가 알려줍니다.

> **주의.** 이 플러그인은 **문서화되지 않은 Apple 비공개 프레임워크**에
> 의존합니다. 지금은 macOS 26.x에서 잘 동작하고 macOS 업데이트 때마다
> 스스로 재검증하지만(빌드 캐시가 OS 빌드 번호 기준), Apple이 언제든
> 바꾸거나 막을 수 있습니다 — 그러면 플러그인은 fallback으로 전환하고
> `/media:doctor`가 알려줍니다. 어떤 보증도 하지 않습니다 —
> [LICENSE](LICENSE) 참고.

## 요구 사항

- **macOS** (26.x / Apple Silicon에서 테스트, 기법은 15.4+ 대상).
- **Xcode Command Line Tools** — 최초 한 번의 빌드용. `git clone`이 되는
  환경이라면 이미 있습니다(없으면 `xcode-select --install`; 없어도
  fallback 모드로 동작합니다).

Homebrew도, Node도, Python도, API 키도 필요 없습니다.

## 문제 해결

| 증상 | 해결 방법 |
| --- | --- |
| `DEGRADED — native helper unavailable` | `xcode-select --install` 후 `/media:doctor --rebuild` |
| macOS 업데이트 후 `PRIMARY READ LIKELY BLOCKED` | `/media:doctor --rebuild`, 계속되면 [이슈를 남겨 주세요](https://github.com/Bangs00/claude-media-control/issues) |
| AppleScript 조작이 **error -1743**으로 실패 | 시스템 설정 → 개인정보 보호 및 보안 → 자동화에서 터미널 앱 허용 (fallback 모드에서만) |
| 재생 중이 아닌데 `now`에 곡이 표시됨 | 앱이 낡은 상태를 보고한 것 — `/media:next`를 실행하거나 플레이어 재시작 |

빌드 로그: `${CLAUDE_PLUGIN_DATA}/build.log`

## 제거

```
/plugin uninstall media@claude-media-control
/plugin marketplace remove claude-media-control
```

제거하면 **컴퓨터가 설치 전 상태로 완전히 돌아갑니다.** 모든 것이 Claude가
관리하는 두 디렉터리(`~/.claude/plugins/cache/…`, `…/data/…`) 안에만
있습니다 — LaunchAgent도, 로그인 항목도, 시스템 패키지도 없습니다.
statusline 배선은 스스로 원복됩니다: 제거 후 첫 틱에 wrapper가 이전
`statusLine`을 복원하고 자기 자신과 백업을 삭제하며 클릭 핸들러 앱도
제거합니다 — 1초 안에 statusline이 원래 모습 그대로
돌아옵니다([자세히](docs/statusline.ko.md)).

무해한 두 가지가 남을 수 있습니다: AppleScript fallback을 썼다면 macOS의
**자동화 허용** 기록(`tccutil reset AppleEvents`로 삭제 가능), 그리고
statusline을 **직접 손으로** 배선했다면 그 파일들 — 사용자의 것이니 직접
지우면 됩니다.

## 로드맵

- **Linux**는 `playerctl`/MPRIS, **Windows**는 SMTC 기반 — dispatcher가
  이미 OS별 backend 구조로 되어 있습니다. 기여 환영합니다.

## 개발

```bash
claude --plugin-dir .          # 체크아웃한 리포에서 플러그인 로드
shellcheck scripts/*.sh        # 린트
npx bats tests/media.bats      # 단위 테스트 (native는 stub으로 대체)
claude plugin validate . --strict
```

CI에서는 위 전부에 더해 macOS 러너에서 strict 모드 native 빌드까지 돌립니다.

## 라이선스

[MIT](LICENSE)입니다. native adapter는 ungive/mediaremote-adapter의
BSD-3-Clause 기법을 포팅했고, ungive/media-control의 CLI/JSON 관례를
참고했습니다 — [native/NOTICE](native/NOTICE) 참고.
