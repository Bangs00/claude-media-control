# claude-media-control

[![CI](https://github.com/Bangs00/claude-media-control/actions/workflows/ci.yml/badge.svg)](https://github.com/Bangs00/claude-media-control/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![macOS](https://img.shields.io/badge/platform-macOS-black)
![Claude Code plugin](https://img.shields.io/badge/Claude%20Code-plugin-d97757)
![Zero dependencies](https://img.shields.io/badge/dependencies-zero-brightgreen)

[English](README.md) | **한국어** | [日本語](README.ja.md) | [简体中文](README.zh-CN.md)

Spotify, Apple Music, 브라우저, VLC — **Mac에서 지금 무엇이 재생 중이든**
Claude Code 안에서 바로 확인하고 조작할 수 있습니다. "지금 무슨 노래야?"라고
물어보고, "음악 잠깐 멈춰줘"라고 말하고, 인터랙티브 리모컨을 띄워 보세요.
OAuth도, API 키도, 앱별 연동 설정도 필요 없고 **Homebrew로 설치할 것도
없습니다**.

![claude-media-control 데모](docs/demo.ko.gif)

## 다른 플러그인과 뭐가 다른가요

기존의 Claude용 Spotify/Apple Music 연동은 하나의 앱에 묶여 있고, OAuth나
AppleScript 설정을 거쳐야 합니다. 이 플러그인은 **macOS 시스템 전역
now-playing 서비스**와 직접 통신하기 때문에, 어떤 앱으로 재생하든 *지금
재생 중인* 플레이어를 그대로 인식하고 조작합니다. 서드파티 의존성도 전혀
없습니다. 필요한 것은 Xcode Command Line Tools뿐인데, `git clone`을 쓸 수
있는 환경이라면 이미 설치되어 있을 겁니다([요구 사항](#요구-사항) 참고).

## 설치

Claude Code에서 두 줄이면 끝납니다. Homebrew 단계는 없습니다:

```
/plugin marketplace add Bangs00/claude-media-control
/plugin install media@claude-media-control
```

처음 media 명령을 실행할 때 작은 native helper를 한 번만 빌드하고(약 2초),
그다음부터는 캐시를 사용합니다. macOS 전용입니다.

## 사용법

자연어로 말해도 되고, slash command나 인터랙티브 메뉴를 써도 됩니다:

| 이렇게 말하면 | …또는 이렇게 | 이런 일이 일어납니다 |
| --- | --- | --- |
| "지금 무슨 노래야?" | `/media:now` | 곡 제목 / 아티스트 / 앱 + 진행 바 표시 |
| "음악 꺼줘" | `/media:pause` · `/media:toggle` | 재생 중인 플레이어 일시정지 / 재개 |
| "다음 곡 틀어줘" | `/media:next` · `/media:prev` | 다음 곡 / 이전 곡 |
| "1:30으로 넘겨줘" | `/media:seek 1:30` | 원하는 위치로 이동 |
| "앨범 커버 보여줘" | `/media:artwork` | 커버 이미지를 저장해서 표시 |
| "오디오 스펙트럼 보여줘" | `/media:spectrum` | 재생 중인 소리의 실시간 주파수 막대 (선택 기능) |
| "소리 좀 줄여줘" | `/media:volume 30` | 시스템 출력 볼륨 확인 / 조절 (0–100) |
| "아까 무슨 노래 나왔었지?" | `/media:history` | 최근에 재생된 곡 목록 (로컬 기록) |
| "에어팟으로 틀어줘" | `/media:output airpods` | 오디오 출력 장치 확인 / 전환 |
| "리모컨 띄워줘" | `/media:menu` | 방향키로 조작하는 인터랙티브 컨트롤러 |
| — | `/media:statusline` | statusline에 보여줄 항목과 배치 선택 |
| — | `/media:config` | 표시 기능 켜고 끄기 (진행 바, statusline, 스펙트럼 등) |
| — | `/media:doctor` | 빌드 / 권한 / fallback 상태 진단 |

원한다면 statusline에 지금 재생 중인 곡을 띄울 수도 있습니다 —
[docs/statusline.ko.md](docs/statusline.ko.md)를 참고하세요. 어떤 항목을
보여줄지(곡 정보, 앱, 진행 바, 시간, 출력 장치, 스펙트럼), 한 줄로 붙일지
여러 줄로 나눌지는 `/media:statusline`에서 고르면 됩니다. 30칸보다 긴
제목은 marquee 방식으로 흘러가고(`statusline.marquee`), 세그먼트에는
기본으로 ANSI 스타일이 입혀져 나옵니다 — 재생 상태에 따라 색이 바뀌는
아이콘과 진행 바, 굵은 제목, 기울임꼴 아티스트, 색을 입힌 스펙트럼(단색,
또는 `spectrum.style`로 켜는 위치 기반 무지개색). 일반 텍스트로 되돌리려면
`/media:config statusline.color off`를 실행하세요(`NO_COLOR` 환경 변수도
지원합니다).

## 동작 원리

macOS에는 다른 앱의 재생 정보를 읽을 수 있는 공개 API가 없습니다. 비공개
프레임워크인 `MediaRemote`가 그 역할을 하지만, macOS 15.4부터는 이 데몬이
Apple이 서명한 프로세스에만 응답합니다. 이 플러그인은
[ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter)와
같은 기법을 씁니다. 작은 Objective-C helper(`native/adapter.m`)를 Apple
플랫폼 바이너리인 `/usr/bin/perl`이 로드하게 해서 entitlement 검사를
통과하는 방식입니다. 재생 조작과 위치 이동도 같은 경로로 처리합니다.

native helper를 빌드할 수 없는 환경이라면(Command Line Tools가 없는 경우)
컴파일이 필요 없는 `osascript`/JXA로 읽기를 대신하고, Spotify와 Apple Music
조작은 앱별 AppleScript로 처리합니다. 지금 어떤 모드로 동작 중인지는
`/media:doctor`가 알려줍니다.

> **주의.** 이 플러그인은 **문서화되지 않은 Apple 비공개 프레임워크**에
> 의존합니다. 지금은 macOS 26.x에서 잘 동작하고 macOS 업데이트 때마다
> 자동으로 재검증되지만(빌드 캐시가 OS 빌드 번호 기준), Apple이 언제든
> 바꾸거나 막을 수 있습니다. 그렇게 되면 플러그인은 fallback 경로로 전환해
> 동작하고, `/media:doctor`가 상황을 알려줍니다. 어떤 보증도 하지 않습니다 —
> [LICENSE](LICENSE)를 참고하세요.

## 오디오 스펙트럼 (선택 기능)

`/media:spectrum`은 지금 재생 중인 소리를 실시간 주파수 막대로 그려 줍니다:

```
63Hz ▂▄▆█▇▅▃▂ ▃▂▁▁ ▁ 16kHz   (peak: 1.2kHz)
```

`--live <초>`를 붙이면 여러 프레임을 연속으로 보여주고,
`/media:statusline`으로 statusline에 미니 스펙트럼을 넣을 수도 있습니다.

막대에는 `spectrum.color` 색이 입혀집니다(기본 cyan).
`/media:config spectrum.style rainbow`로 바꾸면 막대 위치에 따라 앞에서
뒤로 색이 순환합니다(일부러 음량과는 무관하게 만들었습니다). 색은
statusline과 터미널에서 직접 실행할 때 보이고, 채팅 응답에서는 색 없이
문자만 나옵니다.

**소리는 이렇게 캡처합니다.** macOS 14.4부터 공개 API가 된 Core Audio의
*process tap*(`AudioHardwareCreateProcessTap`)으로 시스템 출력 믹스를 읽고,
로컬에서 Accelerate/vDSP FFT로 주파수 대역을 계산합니다. **소리는 절대
컴퓨터 밖으로 나가지 않습니다** — 막대 문자열만 만들어질 뿐, 아무것도
녹음하거나 전송하지 않습니다.

**기본은 꺼져 있습니다.** 음악 제어 플러그인이 오디오 녹음 권한을 요구하면
의심스러운 게 당연하니, 스펙트럼은 직접 켜야만 동작합니다:

```
/media:config display.spectrum on
```

**권한.** process tap이 동작하려면 사용 중인 터미널 앱에 *시스템 오디오
녹음* 권한이 있어야 합니다. macOS는 커맨드라인 도구에는 권한 팝업을 띄워
주지 않으므로 직접 켜야 합니다. 시스템 설정 > 개인정보 보호 및 보안 >
화면 및 시스템 오디오 녹음에서, 음악을 틀어 둔 채 사용 중인
터미널(Terminal, iTerm 등)을 켜 주세요. 이 기능은 fail-closed로 설계되어
있습니다. 음악이 나오는데도 캡처가 무음이면 켜기를 거부하면서 빠진 권한을
알려주고, 나중에 권한이 회수되면 스스로 꺼집니다. 권한 상태는
`/media:doctor`에서 확인할 수 있습니다.

macOS 14.4 이상이 필요합니다. 그보다 낮은 버전에서는 이 기능이 아예 보이지
않고 helper도 컴파일하지 않습니다.

## 재생 히스토리와 출력 장치

`/media:history`는 최근에 재생된 곡을 새것부터 보여줍니다. 기록은 어차피
일어나는 조회(statusline 갱신, `/media:now`, 재생 명령)에 **얹혀서** 남기
때문에 백그라운드 폴링도, 데몬도, 추가 리소스 부담도 없습니다. 로그는
플러그인 데이터 디렉터리에 최근 500곡까지만 보관되고 컴퓨터 밖으로 절대
나가지 않습니다. `/media:config history.record off`로 기록을 멈추고,
`/media:history clear`로 지울 수 있습니다.

`/media:output`은 오디오 출력 장치 목록을 보여주고 그 사이를
전환합니다("에어팟으로 틀어줘") — 공개 CoreAudio API를 쓰므로 별도 권한이
필요 없습니다. statusline에도 현재 장치를 띄울 수 있습니다:
`/media:statusline`에서 `output` 항목을 고르면 됩니다.

## 요구 사항

- **macOS** (macOS 26.x / Apple Silicon에서 테스트했고, 이 기법은 15.4
  이상을 대상으로 합니다). 다른 OS 지원은 로드맵에 있습니다.
- **Xcode Command Line Tools** — 최초 한 번의 native 빌드에 필요합니다.
  `xcode-select --install`로 설치할 수 있는데, 아마 이미 있을 겁니다.
  플러그인을 받을 때 필요한 `git`이 `clang`과 같은 Command Line Tools에
  들어 있으니까요. 없어도 플러그인은 fallback 모드로 동작합니다.

Homebrew도, Node도, Python도, API 키도 필요 없습니다.

## 설치 확인

```
/media:doctor
```

정상적으로 설치됐다면 `verdict: PRIMARY OK`로 끝납니다. `DEGRADED`가 나오면
리포트가 해결 방법을 알려줍니다(대부분 `xcode-select --install` 후
`/media:doctor --rebuild`).

## 문제 해결

| 증상 | 해결 방법 |
| --- | --- |
| `DEGRADED — native helper unavailable` | `xcode-select --install` 실행 후 `/media:doctor --rebuild` |
| macOS 업데이트 후 `PRIMARY READ LIKELY BLOCKED` | `/media:doctor --rebuild` 실행, 그래도 계속되면 [이슈를 남겨 주세요](https://github.com/Bangs00/claude-media-control/issues) |
| AppleScript 조작이 **error -1743**으로 실패 | 시스템 설정 → 개인정보 보호 및 보안 → 자동화에서 터미널 앱을 허용해 주세요 (fallback 모드에서만 필요) |
| 아무것도 재생하지 않는데 `now`에 곡이 표시됨 | 앱이 오래된 상태를 보고한 것입니다. `/media:next`를 실행하거나 플레이어를 재시작해 보세요 |
| 스펙트럼이 무음이거나 `display.spectrum on`이 거부됨 | 시스템 설정 → 개인정보 보호 및 보안에서 터미널 앱에 **시스템 오디오 녹음** 권한을 준 뒤(음악을 틀어 둔 채) 다시 시도하세요. 상태는 `/media:doctor`로 확인합니다 |

빌드 로그는 `${CLAUDE_PLUGIN_DATA}/build.log`에 남습니다.

## 제거

```
/plugin uninstall media@claude-media-control
/plugin marketplace remove claude-media-control
```

제거하면 **컴퓨터가 설치 전 상태로 완전히 돌아갑니다.** 플러그인이 만드는
모든 것은 Claude가 관리하는 두 디렉터리(`~/.claude/plugins/cache/...`,
`~/.claude/plugins/data/...`) 안에만 있고, 제거할 때 둘 다 삭제됩니다.
LaunchAgent도, 로그인 항목도, 홈 디렉터리에 남는 파일도, `settings.json`
수정도, 시스템 패키지도 없습니다. 플러그인은 그 밖의 어디에도 쓰지
않습니다. 임시 앨범 커버는 `$TMPDIR`에 저장되는데, 이곳은 macOS가 알아서
비웁니다.

플러그인 파일이 아니라서 남을 수 있는 것이 두 가지 있는데, 둘 다
무해합니다:

- AppleScript fallback을 썼다면 macOS가 **자동화 허용** 기록("터미널 →
  Spotify/Music")을 시스템 권한 데이터베이스에 남깁니다. 지우고 싶으면
  `tccutil reset AppleEvents`를 실행하세요.
- statusline wrapper를 추가했다면 `~/.claude/statusline-media.sh`를 지우고
  `settings.json`의 `"statusLine"` 값을 원래대로 되돌리면 됩니다.

## 로드맵

- ~~**오디오 스펙트럼** (`/media:spectrum`)~~ — v0.2.0에 나왔습니다 (위 참고).
- **Linux** 지원 — `playerctl`/MPRIS 기반. dispatcher가 이미 OS별 backend
  구조로 되어 있습니다. 기여 환영합니다.
- **Windows** 지원 — SMTC(`GlobalSystemMediaTransportControls`) 기반. 기여
  환영합니다.

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
참고했습니다 — [native/NOTICE](native/NOTICE)를 참고하세요.
