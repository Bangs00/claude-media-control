# Statusline 레시피

[English](recipes.md) | **한국어** | [日本語](recipes.ja.md) | [简体中文](recipes.zh-CN.md)

now-playing 세그먼트에 바로 붙여넣는 완성 look 모음입니다. 하나하나
눈에 익은 실물에 뿌리를 두었습니다 — 인광 터미널, 테이프 덱, 튜너
다이얼, 믹싱 콘솔. 색도 그 실물 자체에서 가져왔습니다. 인광체의
발광선, 안료, 문서로 남은 표준이 그 출처입니다. 아래 모든 명령은 실제
`media.sh config` 검증을 통과했고, 모든 GIF는 렌더러의 실제
출력(초당 1프레임)입니다. (전부 가상의 트랙 — *Modem Chorus*의
*Rented Sunsets*, 가상의 앱 *Aux*에서 재생 중.)

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

## Plasma

검정에 가까운 바탕 위 주황 셀 — 네온 가스 패널입니다. 셀은 켜지거나
꺼지거나 둘 중 하나일 뿐, 중간은 없습니다.

![Plasma 레시피 실제 렌더 (초당 1프레임)](recipes/plasma.gif)

```
/media:config statusline.fields "track,progressbar,time"
/media:config style.progressbar.style blocks
/media:config style.progressbar.playing "#ff6a1a"
/media:config style.progressbar.paused "#a34410"
/media:config style.track.title "bold #ffcba3"
/media:config style.track.artist "italic #c26a2e"
/media:config style.time.elapsed "bold #ff6a1a"
/media:config style.time.total "dim #7a3a12"
```

```
▶︎ Rented Sunsets — Modem Chorus  ███████░░░░░░░░░░░░░  1:32/4:07
```

이 주황은 네온이 실제로 내는 색입니다 — 가시광에서 가장 강한 두 선이
585 nm와 640 nm에 있습니다. 바를 `rise`, `fade`, `corner`로 바꾸면 같은
채움이 한 칸씩이 아니라 한 칸의 8분의 1, 3분의 1, 4분의 1씩 자랍니다.
이 패널의 도트 매트릭스 버전을 원하면 `braille`(부분 칸 쌍둥이는
`stipple`)을 쓰세요.

## Phosphor

검정 위 초록 단색과 꽉 찬 블록 바 — 녹색 인광 CRT 터미널입니다.

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
`#ffb000`/`#cc8400`/`#996300`으로 바꾸세요.

## Goban

점판암의 검정과 대합 조개의 흰색 — 바둑돌입니다. 검은 돌은 더 작아
보이기 때문에 0.3 mm 크게 깎습니다. 그래야 둘이 같은 크기로 보입니다.

![Goban 레시피 실제 렌더 (초당 1프레임)](recipes/goban.gif)

```
/media:config statusline.fields "track,progressbar,time"
/media:config style.progressbar.style dots
/media:config style.progressbar.playing "#f7f3e8"
/media:config style.progressbar.paused "#8a8578"
/media:config style.track.title "bold #f7f3e8"
/media:config style.track.artist "italic #b5a882"
/media:config style.time.elapsed "bold #e8c88a"
/media:config style.time.total "dim #6b6455"
```

```
▶︎ Rented Sunsets — Modem Chorus  ●●●●●●●○○○○○○○○○○○○○  1:32/4:07
```

## Service

모직 위 금사 줄 — 소매의 셰브런입니다. 1777년부터 딱 한 가지를 뜻해
왔습니다. 바로 복무한 시간입니다.

![Service 레시피 실제 렌더 (초당 1프레임)](recipes/service.gif)

```
/media:config statusline.fields "track,progressbar,time"
/media:config style.progressbar.style chevron
/media:config style.progressbar.playing "#c9a227"
/media:config style.progressbar.paused "#8a6f1e"
/media:config style.track.title "bold #e8d9a0"
/media:config style.track.artist "italic #9a8b5e"
/media:config style.time.elapsed "bold #c9a227"
/media:config style.time.total "dim #6b5a2c"
```

```
▶︎ Rented Sunsets — Modem Chorus  ▸▸▸▸▸▸▸▹▹▹▹▹▹▹▹▹▹▹▹▹  1:32/4:07
```

## Platform

반 타일로 끝나는 백색 유약 — 역 벽 타일입니다. 흰색으로 구운 이유는
지하에서 빛을 되던져 주기 때문입니다.

![Platform 레시피 실제 렌더 (초당 1프레임)](recipes/platform.gif)

```
/media:config statusline.fields "track,progressbar,time"
/media:config style.progressbar.style tiles
/media:config style.progressbar.playing "#f2efe6"
/media:config style.progressbar.paused "#1e3a34"
/media:config style.track.title "bold #fdfcf8"
/media:config style.track.artist "italic #8fa8a0"
/media:config style.time.elapsed "bold #f2efe6"
/media:config style.time.total "dim #5c6b66"
```

```
▶︎ Rented Sunsets — Modem Chorus  ■■■■■■■◧□□□□□□□□□□□□  1:32/4:07
```

`◧`는 타협이 아닙니다 — 타일 한 줄은 실제로 반 타일로 끝나고, 그래서
경계 칸에 그릴 것이 있습니다.

## Telegraph

황동과 니스칠 참나무, 그리고 경계에서 굵어져 대시가 되는 점 — 전신의
가장 오래된 규칙입니다. 대시는 점 셋을 붙여 놓은 것이니까요.

![Telegraph 레시피 실제 렌더 (초당 1프레임)](recipes/telegraph.gif)

```
/media:config statusline.fields "track,progressbar,time"
/media:config style.progressbar.style dash
/media:config style.progressbar.playing "#b08d57"
/media:config style.progressbar.paused "#6e5327"
/media:config style.track.title "bold #efe6d0"
/media:config style.track.artist "italic #a1854f"
/media:config style.time.elapsed "bold #d4b06a"
/media:config style.time.total "dim #6e5327"
```

```
▶︎ Rented Sunsets — Modem Chorus  ━━━━━━━┅╌╌╌╌╌╌╌╌╌╌╌╌  1:32/4:07
```

## Cassette

따뜻한 테이프 덱: 카세트 창 바, ♪ 계단 레벨, 크림과 앰버의 글자.

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

40칸 헤어라인 눈금과 붉은 바늘, 그리고 아이스 블루 글자 — 실버 페이스
리시버의 백라이트 튜너 다이얼입니다.

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

## Vernier

경화강과 황동 손잡이. 헤드가 헤어라인 눈금을 미끄러지다 눈금과 눈금
*사이*에 섭니다 — 1631년부터 버니어가 해 온 일이 바로 이것입니다.

![Vernier 레시피 실제 렌더 (초당 1프레임)](recipes/vernier.gif)

```
/media:config statusline.fields "track,progressbar,time"
/media:config style.progressbar.style glide
/media:config style.progressbar.length 36
/media:config style.progressbar.playing "#dfe4e9"
/media:config style.progressbar.paused "#b08d57"
/media:config style.track.title "bold #eef2f5"
/media:config style.track.artist "italic #8d959e"
/media:config style.time.elapsed "bold #b9bec4"
/media:config style.time.total "dim #5c636a"
```

```
▶︎ Rented Sunsets — Modem Chorus  ━━━━━━━━━━━━━╾──────────────────────  1:32/4:07
```

길이가 40이 아니라 36인 이유가 있습니다. `glide` 헤드는 반 칸 위치에서만
`╾`로 갈라지는데, 이 위치에서 40칸 바는 경계에 딱 떨어져 `╾`를 아예
보여주지 않습니다.

## VFD

어두운 바탕 위 청록 세그먼트 — 90년대 하이파이의 형광표시관 전면
패널입니다. 앱 이름이 소스 라벨 역할을 합니다.

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

믹싱 데스크식 2단: 위에 미터와 타임코드, 아래에 트랜스포트와 모니터 —
LED 그린과 레코드 레드.

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
🔉 ▁▄▄▆▄▅▄▇ 35%  ▅▅▅▆▄▄▆▆▆▆▂▂▃▃▅▆▄▅▄▄  1:32/4:07
▶︎ Rented Sunsets — Modem Chorus (Aux)  🎚 Bookshelf Speakers
```

볼륨 미니 미터는 진행 바의 `eq` 문자를 그대로 빌려 쓰기 때문에 함께
출렁입니다.

## Slider wall

크림과 검정, 그리고 붉은 상단 — VU 미터입니다. 바늘을 일부러 느리게
만들어서, 순간음을 쫓는 대신 소리의 크기를 보여 줍니다.

![Slider wall 레시피 실제 렌더 (초당 1프레임)](recipes/slider-wall.gif)

```
/media:config statusline.fields "track,volume,progressbar,time"
/media:config style.progressbar.style bars
/media:config style.progressbar.playing "#f0e3c0"
/media:config style.progressbar.paused "#c44a3d"
/media:config style.volume.style stairs
/media:config style.volume.percent off
/media:config style.track.title "bold #f7efd9"
/media:config style.track.artist "italic #b9a887"
/media:config style.time.elapsed "bold #f0e3c0"
/media:config style.time.total "dim #7d7159"
```

```
▶︎ Rented Sunsets — Modem Chorus  🔉 ▁▂▃  ⣄⡀⢀⣤⣤⣴⣦⣄⣤⣶⣴⣶⣦⣀⣀⣀⣀⣴⣦⣤  1:32/4:07
```

`bars`는 기본음에 비조화 배음과 하위 배음을 얹어 모양을 만듭니다 —
그래서 화음이 아니라 실제 음원처럼 움직입니다. 블록 높이 버전을 원하면
`eq`를 쓰세요. 그게 [Console](#console)입니다.

## Third-octave

늘어나지 않고 제자리에서 춤추는 붉은 LED 기둥 — 1/3 옥타브 분석기입니다.
밴드 중심이 고정이라, 바가 넓어지면 같은 구간을 넓게 보는 게 아니라
스펙트럼을 더 많이 보게 됩니다.

![Third-octave 레시피 실제 렌더 (초당 1프레임)](recipes/third-octave.gif)

```
/media:config statusline.fields "track,progressbar,time"
/media:config style.progressbar.style spectrum
/media:config style.progressbar.playing "#ff2d10"
/media:config style.progressbar.paused "#8c1f0d"
/media:config style.track.title "bold #ffc2ae"
/media:config style.track.artist "italic #d4654a"
/media:config style.time.elapsed "bold #ff7a45"
/media:config style.time.total "dim #8a3f2a"
```

```
▶︎ Rented Sunsets — Modem Chorus  ▄▁▃▆▅▄▆▅▂▃▆▆▄▅▅▃▃▆▆▄  1:32/4:07
```

이 빨강은 최초의 가시광 LED가 내는 색 그대로입니다 — 갈륨 비소 인화물,
655 nm, 1962년. `spectrum`을 `cava`로 바꾸면 같은 분석을 가로 밀도 두
배의 braille 점으로 그립니다.

## Seiche

호수 전체가 그릇 안에서 흔들립니다 — 분지의 폭이 얼마든 그 안에 꼭 맞는
정상파입니다. 그래서 이 바는 길이에 상관없이 늘 같은 물결 두 개 반을
보여 줍니다.

![Seiche 레시피 실제 렌더 (초당 1프레임)](recipes/seiche.gif)

```
/media:config statusline.fields "track,progressbar,time"
/media:config style.progressbar.style wave
/media:config style.progressbar.playing "#3b8fc4"
/media:config style.progressbar.paused "#5f9e79"
/media:config style.track.title "bold #d6ecf5"
/media:config style.track.artist "italic #7fb3cc"
/media:config style.time.elapsed "bold #a5d5ea"
/media:config style.time.total "dim #4a7285"
```

```
▶︎ Rented Sunsets — Modem Chorus  █▇▅▂▁▂▄▇█▇▅▂▁▂▄▇█▇▅▂  1:32/4:07
```

남색에서 초록으로 가는 순서는 호수색 척도가 놓인 방향 그대로입니다 —
seiche에 이름을 붙인 사람이 그 척도도 만들었습니다. `wave`를 `swell`로
바꾸면 braille 쌍둥이가 됩니다.

## Ripple tank

위에 램프, 아래에 물을 담은 쟁반, 가운데를 두드리는 바늘 — 파동이 제
그림자를 중심에서 바깥으로 드리웁니다. 빛이 파동임을 증명하려고 만든
장치입니다.

![Ripple tank 레시피 실제 렌더 (초당 1프레임)](recipes/ripple-tank.gif)

```
/media:config statusline.fields "track,progressbar,time"
/media:config style.progressbar.style mirror
/media:config style.progressbar.playing "#f2ead4"
/media:config style.progressbar.paused "#8a94a6"
/media:config style.track.title "bold #fdfaf0"
/media:config style.track.artist "italic #9fb0c4"
/media:config style.time.elapsed "bold #e8dcbb"
/media:config style.time.total "dim #5c6675"
```

```
▶︎ Rented Sunsets — Modem Chorus  ▇▄▁▁▄▇█▆▃▁▁▃▆█▇▄▁▁▄▇  1:32/4:07
```

같은 모양의 braille 쌍둥이는 `ripple`입니다.

## Lead II

초당 25 밀리미터로 지나가는 트레이스 — 온 세계가 합의한 기록지 속도입니다.
그래서 바가 길어지면 박동이 넓어지는 게 아니라 더 많아집니다.

![Lead II 레시피 실제 렌더 (초당 1프레임)](recipes/lead-ii.gif)

```
/media:config statusline.fields "track,progressbar,time"
/media:config style.progressbar.style heartbeat
/media:config style.progressbar.length 40
/media:config style.progressbar.playing "#55f5a1"
/media:config style.progressbar.paused "#6f8fa8"
/media:config style.track.title "bold #c9fdde"
/media:config style.track.artist "italic #3fbc7b"
/media:config style.time.elapsed "bold #55f5a1"
/media:config style.time.total "dim #2e8f5c"
```

```
▶︎ Rented Sunsets — Modem Chorus  ━┻┳━━━━━━━━┻┳━━━━━━━━┻┳━━━━━━━━┻┳━━━━━━━  1:32/4:07
```

초록은 장잔광 표시관 인광체의 색이고, 일시정지 색이 빨강도 노랑도 아닌
것은 의도한 것입니다. 모니터에서 그 둘은 표준으로 정해진 경보색인데,
일시정지한 곡은 경보가 아니니까요. `heartbeat`를 `monitor`로 바꾸면
braille로 그리는데, 행이 넉넉해서 스파이크뿐 아니라 작은 P와 T
봉우리까지 보여 줍니다. `ekg`는 기준선을 중심으로 그리는 대신 바닥에서
위로 박동을 그립니다.

## Night drive

밤 운전용 앰버 계기 불빛 — 일시정지하면 액센트가 빨간 경고등으로
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

크롬 시안 제목 아래 핫핑크 pulse — 네온 그리드 선셋 팔레트입니다.

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
▶︎ Rented Sunsets — Modem Chorus  ▄▁▁▁▁▁▁█▁▁▄▁▁▁▁▁▁█▁▁  1:32/4:07
```

## Lo-fi

먼지 낀 파스텔과 음표가 행진하는 짧은 바 — 차분하고 대비가 낮은
스터디 비트.

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
▶︎ Rented Sunsets — Modem Chorus  ·♫♪♫··♪♫♪··♫  1:32/4:07
```

## Neko

따뜻한 종이색으로 점선 길을 걸어가는 고양이 — 터미널의 생물입니다.
무언가가 데스크톱을 걸어 다니기 한참 전에 이미 커맨드라인을 걷고
있었습니다.

![Neko 레시피 실제 렌더 (초당 1프레임)](recipes/neko.gif)

```
/media:config statusline.fields "track,progressbar,time"
/media:config style.progressbar.style cat
/media:config style.progressbar.playing "#f4e4c1"
/media:config style.progressbar.paused "#8a7f6a"
/media:config style.track.title "bold #fbf3e2"
/media:config style.track.artist "italic #b3a488"
/media:config style.time.elapsed "bold #f4e4c1"
/media:config style.time.total "dim #6f6656"
```

```
▶︎ Rented Sunsets — Modem Chorus  ━━━━━━ᓚᘏᗢ┈┈┈┈┈┈┈┈┈┈┈  1:32/4:07
```

`snake`, `duck`, `bird`는 각자의 길을 걷고, `sprite`는 원하는 프레임을
그대로 받습니다:

```
/media:config style.progressbar.style sprite
/media:config style.progressbar.sprite "◐ ◓ ◑ ◒"
/media:config style.progressbar.trail "═"
/media:config style.progressbar.track "┈"
```

색이 전혀 필요 없는 유일한 계열입니다 — 생물이 트랙의 현재 위치에 서
있으니, 위치만으로 진행도가 읽힙니다.

## Twilight

부드러운 인디고와 페리윙클, 라벤더를 smooth 바 위에 — 요즘 다크 테마의
파스텔 look입니다.

![Twilight 레시피 실제 렌더 (초당 1프레임)](recipes/twilight.gif)

```
/media:config style.progressbar.style smooth
/media:config style.progressbar.playing "#79a0f5"
/media:config style.progressbar.paused "#dfae66"
/media:config style.track.title "bold #bfc9f4"
/media:config style.track.artist "italic #ba99f5"
/media:config style.app "#555e87"
/media:config style.time.elapsed "bold #7bcdfd"
/media:config style.time.total "dim #555e87"
```

```
▶︎ Rented Sunsets — Modem Chorus (Aux)  ███████▌░░░░░░░░░░░░  1:32/4:07
```

truecolor가 안 된다면(Apple Terminal 등) 헥스 키만 named color로 바꾸면
됩니다 — 이 페이지의 어느 레시피에나 같은 패턴이 통합니다:

```
/media:config style.progressbar.playing bright-blue
/media:config style.progressbar.paused yellow
/media:config style.track.title "bold bright-white"
/media:config style.track.artist "italic bright-magenta"
/media:config style.time.elapsed "bold bright-cyan"
/media:config style.app reset
/media:config style.time.total reset
```
