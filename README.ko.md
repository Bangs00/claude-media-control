# claude-media-control

[![CI](https://github.com/Bangs00/claude-media-control/actions/workflows/ci.yml/badge.svg)](https://github.com/Bangs00/claude-media-control/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
![macOS](https://img.shields.io/badge/platform-macOS-black)
![Claude Code plugin](https://img.shields.io/badge/Claude%20Code-plugin-d97757)
![Zero dependencies](https://img.shields.io/badge/dependencies-zero-brightgreen)

[English](README.md) | **한국어** | [日本語](README.ja.md) | [简体中文](README.zh-CN.md)

**Mac에서 재생 중인 모든 미디어** — Spotify, Apple Music, 브라우저, VLC — 를
Claude Code에서 바로 확인·제어 가능. "지금 무슨 노래야?"라고 묻거나, "음악
일시정지해줘"라고 말하거나, 인터랙티브 리모컨 실행 가능. OAuth 없음, API 키
없음, 앱별 통합 없음, **Homebrew로 설치할 것도 없음**.

![claude-media-control 데모](docs/demo.ko.gif)

## 왜 이 플러그인인가

- 기존 Claude/Spotify/Apple Music 통합은 각각 하나의 앱에 종속되며 OAuth/AppleScript 설정 필요
- 본 플러그인은 **macOS 시스템 전역 now-playing 서비스**와 통신 — 어떤 앱이든 *현재 활성* 플레이어를 인식·제어하며 **서드파티 의존성 zero**
- 유일한 요구 사항은 Xcode Command Line Tools — `git clone`이 가능한 환경이라면 이미 설치되어 있음 ([요구 사항](#요구-사항) 참고)

## 설치

Claude Code 안에서 두 줄이면 완료 — Homebrew 단계 없음:

```
/plugin marketplace add Bangs00/claude-media-control
/plugin install media@claude-media-control
```

- 첫 media 명령 실행 시 소형 native helper 빌드(~2초, 최초 1회), 이후 캐시 사용
- macOS 전용

## 사용법

자연어, slash command, 인터랙티브 메뉴 모두 지원:

| 이렇게 말하면 | …또는 실행 | 동작 |
| --- | --- | --- |
| "지금 무슨 노래야?" | `/media:now` | 현재 제목 / 아티스트 / 앱 + progress bar |
| "음악 꺼줘" / "pause the music" | `/media:pause` · `/media:toggle` | 활성 플레이어 일시정지 / 재개 |
| "다음 곡" | `/media:next` · `/media:prev` | 다음 곡 / 이전 곡 |
| "1:30으로 이동해줘" | `/media:seek 1:30` | 절대 위치로 seek |
| "앨범 아트 보여줘" | `/media:artwork` | 커버 저장 후 표시 |
| "오디오 스펙트럼 보여줘" | `/media:spectrum` | 재생 중인 오디오의 실시간 주파수 바 (opt-in) |
| "소리 줄여줘" | `/media:volume 30` | 시스템 출력 볼륨 확인 / 설정 (0–100) |
| "리모컨 줘" | `/media:menu` | 인터랙티브 컨트롤러 (방향키 메뉴) |
| — | `/media:statusline` | now-playing statusline 표시 항목 + 레이아웃 선택 |
| — | `/media:config` | 표시 기능 토글 (progress bar, statusline, 스펙트럼) |
| — | `/media:doctor` | 빌드 / 권한 / fallback 진단 |

선택 사항 — statusline에 now-playing 표시 가능 ([docs/statusline.ko.md](docs/statusline.ko.md) 참고):

- `/media:statusline`으로 표시 항목(track, progress bar, time, spectrum)과 줄 배치(항목별 줄 분리 여부) 선택
- 세그먼트는 ANSI 스타일 적용 상태로 출력 — 재생 상태 색상의 아이콘·progress bar, bold 제목, italic 아티스트, 색조 적용 스펙트럼(단색 또는 `spectrum.style`의 위치 기반 rainbow)
- `/media:config statusline.color off`(또는 `NO_COLOR`)로 일반 텍스트 복원

## 동작 원리

- macOS에는 다른 앱의 now-playing 정보를 읽는 공개 API가 없음. 비공개 `MediaRemote` framework가 이를 제공하지만, macOS 15.4부터 해당 daemon은 Apple이 서명한 프로세스에만 응답
- 본 플러그인은 [ungive/mediaremote-adapter](https://github.com/ungive/mediaremote-adapter)와 동일한 기법 사용: 소형 Objective-C helper(`native/adapter.m`)를 Apple 플랫폼 바이너리인 `/usr/bin/perl`이 로드하여 entitlement 검사 통과. 재생 명령과 seek도 같은 경로 사용
- native helper 빌드가 불가한 경우(Command Line Tools 없음): 읽기는 `osascript`/JXA 기반 컴파일 불필요 경로로, Spotify·Apple Music 제어는 앱별 AppleScript로 fallback. 현재 모드는 `/media:doctor`로 확인

> **면책 조항.** 본 플러그인은 **비공개·비문서화 Apple framework**에 의존함.
> 현재 macOS 26.x에서 동작하며 macOS 업데이트 후마다 자동 재검증됨(빌드
> 캐시가 OS 빌드 번호 기준으로 키됨). 다만 Apple이 언제든 변경·차단 가능하며,
> 그 경우 플러그인은 fallback 경로로 degrade되고 `/media:doctor`가 이를 보고함.
> 무보증 — [LICENSE](LICENSE) 참고.

## 오디오 스펙트럼 (opt-in)

`/media:spectrum`은 재생 중인 오디오의 실시간 주파수 바 뷰를 렌더링:

```
63Hz ▂▄▆█▇▅▃▂ ▃▂▁▁ ▁ 16kHz   (peak: 1.2kHz)
```

- `--live <seconds>`로 여러 프레임 스트리밍 가능
- `/media:statusline`으로 statusline에 미니 스펙트럼 추가 가능

바 색조는 `spectrum.color` 적용(기본 cyan):

- `/media:config spectrum.style rainbow` 설정 시 바 위치 기반 front-to-back 색상 순환(의도적으로 음량 기반이 아님)
- 색조는 statusline과 직접 터미널 실행에서 표시, 채팅 응답은 일반 글리프 유지

**오디오 캡처 방식**

- Core Audio *process tap*(`AudioHardwareCreateProcessTap`, macOS 14.4부터 공개 API)이 시스템 출력 믹스를 읽고, 로컬 Accelerate/vDSP FFT가 밴드로 변환
- **오디오는 절대 기기 밖으로 나가지 않음** — 바 문자열만 생성되며, 어떤 것도 녹음·전송되지 않음

**기본 off.** 음악 제어 플러그인의 오디오 녹음 권한 요구는 경계 대상이므로 스펙트럼은 opt-in:

```
/media:config display.spectrum on
```

**권한**

- tap 동작에는 터미널 앱에 대한 *시스템 오디오 녹음* 권한 필요
- macOS는 command-line 도구에 자동 프롬프트를 표시하지 **않으므로** 수동 부여 필요: 시스템 설정 > 개인정보 보호 및 보안 > 화면 및 시스템 오디오 녹음에서, 오디오 재생 중에 터미널(Terminal, iTerm, …) 활성화
- 활성화는 fail-closed — 오디오 재생 중에도 캡처가 무음이면 거부하고 누락된 권한을 안내, 이후 권한 회수 시 기능 자동 비활성화
- 권한 상태는 `/media:doctor`가 보고

macOS 14.4+ 필요. 이전 시스템에서는 기능이 숨겨지며 helper도 컴파일되지 않음.

## 요구 사항

- **macOS** (macOS 26.x / Apple Silicon에서 테스트, 기법 자체는 15.4+ 대상). 다른 OS는 로드맵 참고
- **Xcode Command Line Tools** — 최초 1회 native 빌드용. `xcode-select --install`로 설치. 플러그인 clone에 필요한 `git`이 `clang`과 동일한 Command Line Tools에 포함되므로 이미 설치되어 있을 가능성이 높음. 없어도 플러그인은 fallback 모드로 동작

Homebrew, Node, Python, API 키 모두 불필요.

## 설치 확인

```
/media:doctor
```

- 정상 설치는 `verdict: PRIMARY OK`로 종료
- `DEGRADED`인 경우 리포트가 해결책 안내 (보통 `xcode-select --install` 후 `/media:doctor --rebuild`)

## 문제 해결

| 증상 | 해결 |
| --- | --- |
| `DEGRADED — native helper unavailable` | `xcode-select --install` 후 `/media:doctor --rebuild` |
| macOS 업데이트 후 `PRIMARY READ LIKELY BLOCKED` | `/media:doctor --rebuild`, 지속 시 [이슈 등록](https://github.com/Bangs00/claude-media-control/issues) 요청 |
| AppleScript 제어가 **error -1743**으로 실패 | 시스템 설정 → 개인정보 보호 및 보안 → 자동화에서 터미널 앱 승인 (fallback 모드 전용) |
| 재생 중이 아닌데 `now`가 트랙을 표시 | 앱이 오래된 상태를 보고한 것 — `/media:next` 실행 또는 플레이어 재시작 |
| 스펙트럼이 무음이거나 `display.spectrum on` 거부됨 | 시스템 설정 → 개인정보 보호 및 보안에서 터미널 앱에 **시스템 오디오 녹음** 권한 부여(오디오 재생 중) 후 재시도, 상태는 `/media:doctor`로 확인 |

빌드 로그 위치: `${CLAUDE_PLUGIN_DATA}/build.log`

## 제거

```
/plugin uninstall media@claude-media-control
/plugin marketplace remove claude-media-control
```

제거 시 **기기가 설치 전 상태로 완전히 복원됨:**

- 플러그인이 생성하는 모든 것은 Claude가 관리하는 두 디렉터리(`~/.claude/plugins/cache/...`, `~/.claude/plugins/data/...`)에 존재하며, 둘 다 제거 시 삭제됨
- LaunchAgent 없음, 로그인 항목 없음, 홈 디렉터리 파일 없음, `settings.json` 수정 없음, 시스템 패키지 없음
- 플러그인은 그 외 어디에도 기록하지 않음. 임시 아트워크는 `$TMPDIR`에 저장되며 macOS가 자체 정리

플러그인 파일이 아니어서 남을 수 있는 것 두 가지 (둘 다 무해):

- AppleScript fallback 사용 시 macOS가 **자동화 승인**("터미널 → Spotify/Music")을 시스템 권한 데이터베이스에 유지 — 원하면 `tccutil reset AppleEvents`로 제거 가능
- 선택 사항인 statusline wrapper 추가 시 `~/.claude/statusline-media.sh` 삭제 및 `settings.json`의 이전 `"statusLine"` 값 복원 필요

## 로드맵

- ~~**오디오 스펙트럼** (`/media:spectrum`)~~ — v0.2.0에서 출시 (위 참고)
- **Linux** backend — `playerctl`/MPRIS 사용, dispatcher는 이미 OS별 backend 구조로 설계됨 — 기여 환영
- **Windows** backend — SMTC(`GlobalSystemMediaTransportControls`) 사용 — 기여 환영

## 개발

```bash
claude --plugin-dir .          # checkout에서 플러그인 로드
shellcheck scripts/*.sh        # lint
npx bats tests/media.bats      # unit test (native는 stub 처리)
claude plugin validate . --strict
```

CI는 위 전체 + macOS runner에서의 strict native 빌드 실행.

## 라이선스

[MIT](LICENSE). native adapter는 ungive/mediaremote-adapter의 BSD-3-Clause
기법을 포팅했으며, ungive/media-control의 CLI/JSON 규약을 참조함 —
[native/NOTICE](native/NOTICE) 참고.
