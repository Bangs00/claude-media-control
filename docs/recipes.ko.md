# Statusline 레시피

[English](recipes.md) | **한국어** | [日本語](recipes.ja.md) | [简体中文](recipes.zh-CN.md)

now-playing 세그먼트에 바로 붙여넣는 완성 look 모음입니다. 하나하나 실제로
알아볼 수 있는 대상에 뿌리를 두었습니다 — 인광 터미널, 테이프 덱, 튜너
다이얼, 믹싱 콘솔. 아래 모든 명령은 실제 `media.sh config` 검증을
통과했고, 모든 GIF는 렌더러의 실제 출력(초당 1프레임)입니다. (전부 가상의
트랙 — *Modem Chorus*의 *Rented Sunsets*, 가상의 앱 *Aux*에서 재생 중.)

적용 방법: 블록의 줄을 한 줄씩 Claude에 붙여넣거나, 블록째 건네며 "이대로
적용해줘"라고 하면 됩니다. 변경은 다음 statusline 틱에 바로 반영됩니다 —
재시작 없음.

각 레시피는 **기본(stock) 상태**를 시작점으로 삼습니다. 다른 레시피나
직접 만든 설정에서 넘어온다면 먼저 초기화하세요 — 빠져나오는 길도 같은
명령입니다:

```
/media:config statusline reset
```

(키별 상세는 [스타일 갤러리](styles.ko.md), 초기화 계열은 [기본값으로
되돌리기](styles.ko.md#기본값으로-되돌리기) 참고.)

헥스 색은 24-bit truecolor로 그려집니다 — 대부분의 터미널이 지원하지만
Apple Terminal은 아닙니다. [Twilight](#twilight) 끝에 어느 레시피에나
통하는 named-color 대체 패턴이 있습니다.

## Zen

제목과 현재 위치만 — marquee까지 꺼서, 움직이는 것은 시계뿐입니다.

![Zen 레시피 실제 렌더 (초당 1프레임)](recipes/zen.gif)

```
/media:config statusline.fields "track,time"
/media:config style.track.artist off
/media:config style.time.total off
/media:config statusline.marquee off
```

```
▶︎ Rented Sunsets  1:32
```

## Mono

검정 위 흰색과 가는 line 바 — 포켓 플레이어 OLED 화면의 look. named color만
씁니다.

![Mono 레시피 실제 렌더 (초당 1프레임)](recipes/mono.gif)

```
/media:config statusline.fields "track,progressbar,time"
/media:config style.progressbar.playing bright-white
/media:config style.progressbar.paused bright-black
/media:config style.track.title "bold bright-white"
/media:config style.track.artist "italic bright-black"
/media:config style.time.elapsed "bold bright-white"
/media:config style.time.total "dim white"
```

```
▶︎ Rented Sunsets — Modem Chorus  ━━━━━━━─────────────  1:32/4:07
```

## Hardcopy

순수 ASCII에 무색 — 인쇄된 터미널 로그 같은 모습. 플레인 터미널과
`NO_COLOR` 환경용.

![Hardcopy 레시피 실제 렌더 (초당 1프레임)](recipes/hardcopy.gif)

```
/media:config statusline.fields "track,progressbar,time"
/media:config style.progressbar.style retro
/media:config statusline.color off
/media:config statusline.marquee off
```

```
▶︎ Rented Sunsets — Modem Chorus  =======-------------  1:32/4:07
```

## Phosphor

검정 위 초록 단색과 통짜 블록 바 — 그린 인광 CRT 터미널.

![Phosphor 레시피 실제 렌더 (초당 1프레임)](recipes/phosphor.gif)

```
/media:config statusline.fields "track,progressbar,time"
/media:config style.progressbar.style "█ "
/media:config style.progressbar.playing "#33ff33"
/media:config style.progressbar.paused "#22aa22"
/media:config style.track.title "bold #33ff33"
/media:config style.track.artist "#22bb33"
/media:config style.time.elapsed "bold #33ff33"
/media:config style.time.total "dim #33ff33"
```

```
▶︎ Rented Sunsets — Modem Chorus  ███████               1:32/4:07
```

앰버 인광 버전을 원하면 `#33ff33`/`#22bb33`/`#22aa22`를
`#ffb000`/`#cc8400`/`#996300`으로 바꾸면 됩니다.

## Cassette

따뜻한 테이프 덱: 카세트 창 바, ♪ 계단 레벨, 크림-앰버 레터링.

![Cassette 레시피 실제 렌더 (초당 1프레임)](recipes/cassette.gif)

```
/media:config statusline.fields "track,volume,progressbar,time"
/media:config style.progressbar.style cassette
/media:config style.progressbar.playing "#e8863a"
/media:config style.progressbar.paused "#c94f3d"
/media:config style.volume.style stairs
/media:config style.volume.icon ♪
/media:config style.volume.percent off
/media:config style.track.title "bold #f2e3c6"
/media:config style.track.artist "italic #d9a066"
/media:config style.time.elapsed "bold #f2e3c6"
/media:config style.time.total "dim #d9a066"
```

```
▶︎ Rented Sunsets — Modem Chorus  ♪ ▁▂▃  ▮▮▮▮▮▮▮▯▯▯▯▯▯▯▯▯▯▯▯▯  1:32/4:07
```

## Dial

40칸 헤어라인 눈금 위 빨간 바늘 — 실버 페이스 리시버의 백라이트 튜너
다이얼, 아이스 블루 레터링.

![Dial 레시피 실제 렌더 (초당 1프레임)](recipes/dial.gif)

```
/media:config statusline.fields "track,progressbar,time"
/media:config style.progressbar.style playhead
/media:config style.progressbar.length 40
/media:config style.progressbar.playing "#ff6b6b"
/media:config style.progressbar.paused "#e5c25b"
/media:config style.track.title "bold #a9d1ff"
/media:config style.track.artist "italic #6f9fd8"
/media:config style.time.elapsed "bold #a9d1ff"
/media:config style.time.total "dim #6f9fd8"
```

```
▶︎ Rented Sunsets — Modem Chorus  ──────────────╼╾────────────────────────  1:32/4:07
```

## VFD

어두운 바탕 위 청록 세그먼트 — 90년대 하이파이 전면 VFD 패널. 앱 이름이
소스 라벨 노릇을 합니다.

![VFD 레시피 실제 렌더 (초당 1프레임)](recipes/vfd.gif)

```
/media:config statusline.fields "track,app,volume,progressbar,time"
/media:config style.progressbar.style tape
/media:config style.progressbar.playing "#3ef0c0"
/media:config style.progressbar.paused "#e8a33d"
/media:config style.volume.style progress
/media:config style.volume.icon none
/media:config style.volume.percent "dim #57d9c0"
/media:config style.track.title "bold #b8fff0"
/media:config style.track.artist "italic #57d9c0"
/media:config style.app "#2e9c88"
/media:config style.time.elapsed "bold #b8fff0"
/media:config style.time.total "dim #57d9c0"
```

```
▶︎ Rented Sunsets — Modem Chorus (Aux)  ▰▰▰▱▱▱▱▱ 35%  ▰▰▰▰▰▰▰▱▱▱▱▱▱▱▱▱▱▱▱▱  1:32/4:07
```

## Console

믹싱 데스크식 2단 배치: 위에는 미터와 타임코드, 아래에는 트랜스포트와 모니터
— LED 그린, 레코드 레드.

![Console 레시피 실제 렌더 (초당 1프레임)](recipes/console.gif)

```
/media:config statusline.fields "volume,progressbar,time,/,track,app,output"
/media:config style.progressbar.style eq
/media:config style.progressbar.playing green
/media:config style.progressbar.paused red
/media:config style.volume.style progress
/media:config style.time.elapsed "bold yellow"
/media:config style.output.icon 🎚
```

```
🔉 ▅▆▂▁▁▁▁▁ 35%  ▅▆▂▇▃█▅▁▁▁▁▁▁▁▁▁▁▁▁▁  1:32/4:07
▶︎ Rented Sunsets — Modem Chorus (Aux)  🎚 Bookshelf Speakers
```

볼륨 미니 미터는 진행 바의 `eq` 문자를 그대로 빌려 함께 들썩입니다.

## Night drive

야간 주행의 앰버 계기판 글로우 — 일시정지하면 강조색이 빨간 경고등으로
바뀝니다.

![Night drive 레시피 실제 렌더 (초당 1프레임)](recipes/night-drive.gif)

```
/media:config statusline.fields "track,progressbar,time"
/media:config style.progressbar.style knob
/media:config style.progressbar.playing "#ff9f0a"
/media:config style.progressbar.paused "#ff453a"
/media:config style.track.title "bold #ffb257"
/media:config style.track.artist "italic #c77f3d"
/media:config style.time.elapsed "bold #ff9f0a"
/media:config style.time.total "dim #c77f3d"
```

```
▶︎ Rented Sunsets — Modem Chorus  ━━━━━━●─────────────  1:32/4:07
```

## Synthwave

크롬-시안 제목 아래 핫핑크 펄스 — 네온 그리드 선셋 팔레트.

![Synthwave 레시피 실제 렌더 (초당 1프레임)](recipes/synthwave.gif)

```
/media:config statusline.fields "track,progressbar,time"
/media:config style.progressbar.style pulse
/media:config style.progressbar.playing "#ff2975"
/media:config style.progressbar.paused "#8c1eff"
/media:config style.track.title "bold underline #36f9f6"
/media:config style.track.artist "italic #ff2975"
/media:config style.time.elapsed "bold #ffd319"
/media:config style.time.total "dim #f222ff"
```

```
▶︎ Rented Sunsets — Modem Chorus  ▁▄▂▂█▁▄▁▁▁▁▁▁▁▁▁▁▁▁▁  1:32/4:07
```

## Lo-fi

먼지 앉은 파스텔과 짧은 음표 바 — 차분한 저대비 스터디 비트.

![Lo-fi 레시피 실제 렌더 (초당 1프레임)](recipes/lo-fi.gif)

```
/media:config statusline.fields "track,progressbar,time"
/media:config style.progressbar.style notes
/media:config style.progressbar.length 12
/media:config style.progressbar.playing "#d6b2c2"
/media:config style.progressbar.paused "#b7a9c6"
/media:config style.track.title "bold #e4cba8"
/media:config style.track.artist "italic #a4c8e1"
/media:config style.time.elapsed "#d6b2c2"
/media:config style.time.total "dim #b7a9c6"
```

```
▶︎ Rented Sunsets — Modem Chorus  ♪♫♪♫········  1:32/4:07
```

## Twilight

smooth 바 위 인디고·페리윙클·라벤더 파스텔 — 모던 다크 테마의 파스텔 look,
전부 정확한 헥스로.

![Twilight 레시피 실제 렌더 (초당 1프레임)](recipes/twilight.gif)

```
/media:config style.progressbar.style smooth
/media:config style.progressbar.playing "#7aa2f7"
/media:config style.progressbar.paused "#e0af68"
/media:config style.track.title "bold #c0caf5"
/media:config style.track.artist "italic #bb9af7"
/media:config style.app "#565f89"
/media:config style.time.elapsed "bold #7dcfff"
/media:config style.time.total "dim #565f89"
```

```
▶︎ Rented Sunsets — Modem Chorus (Aux)  ███████▌░░░░░░░░░░░░  1:32/4:07
```

truecolor가 없는 터미널(예: Apple Terminal)이라면 헥스 키만 named color로
갈아끼우세요 — 이 페이지의 어느 레시피에도 같은 패턴이 통합니다:

```
/media:config style.progressbar.playing bright-blue
/media:config style.progressbar.paused yellow
/media:config style.track.title "bold bright-white"
/media:config style.track.artist "italic bright-magenta"
/media:config style.time.elapsed "bold bright-cyan"
/media:config style.app reset
/media:config style.time.total reset
```
