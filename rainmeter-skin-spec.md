# Rainmeter Skin Suite 명세서 — "Umber"

> 이 문서는 Claude Code가 Rainmeter 스킨을 구현하기 위한 명세서다.
> 구현 전에 **"0. 작업 원칙"**을 먼저 읽고, 불확실한 부분(플러그인 버전 등)은 반드시 최신 문서로 확인한 뒤 진행할 것.

---

## 0. 작업 원칙 (Claude Code에게)

1. **대상 환경**: Windows 10/11, Rainmeter 4.5 이상 (최신 안정 버전 기준). 해상도·DPI 독립적으로 동작해야 함.
2. **외부 플러그인은 최소화**한다. 기본 내장(Built-in) measure/plugin으로 가능한 건 내장으로 구현.
   - 외부 플러그인이 필요한 곳: 음악 플레이어(WebNowPlaying) 단 하나.
   - 오디오 비주얼라이저는 내장 `AudioLevel` 플러그인 사용.
3. **플러그인/API 정보는 학습 데이터에 의존하지 말고** 구현 직전 공식 저장소·문서에서 현재 버전과 옵션 이름을 확인할 것. 확인 못 한 부분은 코드 주석에 `TODO(verify)`로 남길 것.
4. 모든 위젯은 **독립 스킨(config)** 으로 만든다. 사용자가 개별로 켜고 끄고 위치를 옮길 수 있어야 함.
5. 색상·폰트·크기·간격 등 **디자인 값은 하드코딩 금지**. 전부 공용 변수 파일에서 참조 (색 변경 가능성 있음).
6. 비밀값(구글 캘린더 iCal 주소)은 **별도 파일**로 분리하고 `.gitignore`에 포함.
7. 최종 산출물은 `.rmskin` 패키지로 빌드 가능한 구조여야 함 (Rainmeter Skin Packager 호환).
8. 단계별로 구현하고, 각 단계 끝에 Rainmeter 로그(About → Log)에 에러/경고가 없는지 확인하는 방법을 사용자에게 안내할 것.

---

## 1. 전체 개요

| 항목 | 내용 |
|---|---|
| 스위트 이름 | `Umber` (가칭, 변경 가능) |
| UI 언어 | **영어** (모든 라벨, 요일, 월 이름, 툴팁) |
| 디자인 톤 | 반투명 갈색 배경, 깔끔한 미니멀 UI, 둥근 모서리, 얇은 구분선 |
| 위젯 목록 | Clock, Calendar(Google), System(CPU·RAM), Network, Music Player(Spotify + Visualizer) |
| 선택 위젯 | 위 5개 완료 후 여유 있으면: Disk, Weather (지금은 범위 밖) |

---

## 2. 폴더 구조

```
Umber/
├── @Resources/
│   ├── Variables.inc          # 색상·폰트·크기 등 공용 디자인 변수
│   ├── Styles.inc             # 공용 MeterStyle (배경, 제목, 본문, 보조 텍스트, 바 등)
│   ├── Secrets.inc            # iCal 비공개 주소 (git 제외)
│   ├── Secrets.example.inc    # 템플릿 (빈 값 + 설명 주석)
│   ├── Scripts/
│   │   ├── Calendar.lua       # 달력 그리드 생성
│   │   └── ICalParser.lua     # .ics 파싱 + 반복 일정 전개
│   ├── Fonts/                 # 번들 폰트 (라이선스 허용되는 것만)
│   └── Images/                # 아이콘 (SVG→PNG 또는 Shape 미터로 대체)
├── Clock/Clock.ini
├── Calendar/Calendar.ini
├── System/System.ini
├── Network/Network.ini
├── Music/Music.ini
├── Settings/Settings.ini      # (선택) 테마 색상 바꾸는 설정 스킨
├── .gitignore                 # Secrets.inc, *.ics 캐시 제외
└── README.md                  # 설치·설정 가이드 (영어 또는 한국어)
```

---

## 3. 디자인 시스템

### 3.1 색상 (`Variables.inc`)
Rainmeter 색상 형식 `R,G,B,A` 사용. **모든 미터는 이 변수만 참조**한다.

```ini
[Variables]
; ---- Theme: Umber (brown) ----
ColorBg=45,32,24,170          ; 반투명 다크 브라운 배경 (알파 ~65%)
ColorBgAlt=70,50,38,140       ; 카드 내부 강조 영역
ColorBorder=160,120,90,80     ; 얇은 테두리
ColorTextPrimary=242,232,220,255   ; 크림색 본문
ColorTextSecondary=190,170,150,255 ; 보조 텍스트
ColorAccent=214,154,96,255    ; 앰버/카라멜 포인트 컬러
ColorAccentDim=214,154,96,90  ; 바 배경, 비활성
ColorWarn=220,110,80,255      ; 고부하 경고

; ---- Typography ----
FontFace=Segoe UI             ; 기본값. TODO: Inter / Manrope 등 번들 시 교체
FontFaceNum=Segoe UI Semibold ; 숫자(시계 등)
FontSizeXL=42
FontSizeL=16
FontSizeM=11
FontSizeS=9

; ---- Layout ----
Radius=12
Pad=14
Gap=8
WidgetWidth=260
```

- 테마 교체를 쉽게 하기 위해 `Themes/Brown.inc`, `Themes/Slate.inc` 등으로 분리하고 `Variables.inc`에서 `@Include`로 하나를 고르는 구조를 권장.
- (선택) `Settings` 스킨에서 프리셋 클릭 시 `!WriteKeyValue` + `!RefreshGroup Umber`로 전체 반영.

### 3.2 공통 스타일 규칙
- 배경: `Shape` 미터의 `Rectangle ... ,#Radius#` + `Fill Color #ColorBg#` + `StrokeWidth 1`, `Stroke Color #ColorBorder#`.
- 위젯 상단에 작은 대문자 제목 (예: `SYSTEM`, `NETWORK`) — `ColorTextSecondary`, 자간 약간.
- 모든 위젯은 `Group=Umber`로 묶어 일괄 refresh 가능하게.
- `AntiAlias=1`, `DynamicWindowSize=1` 기본.
- 숫자 표시 폭이 바뀌어도 레이아웃이 흔들리지 않게 고정 폭/우측 정렬 처리.
- 기본 `Update=1000`. 비주얼라이저만 예외(아래 참고).
- 마우스 오버 시 배경 알파가 살짝 올라가는 정도의 은은한 hover 효과 (선택).

---

## 4. 위젯별 명세

### 4.1 Clock
- 표시: `HH:mm` 큰 숫자 + 초는 작게 (옵션) / 아래에 `Tuesday, November 17` 형식 날짜.
- 12/24시간 전환 변수 `Use24h=1`.
- 로캘 영어 고정: `Measure=Time`에 `TimeStampLocale=en-US` 지정해 요일/월 이름이 OS 언어(한국어)와 무관하게 영어로 나오게 할 것.
- (선택) 보조 타임존 1개 표시 변수.

### 4.2 Calendar (Google Calendar 연동)

#### 연동 방식: iCal 비공개 주소 — 채택
구글 캘린더 → 설정 → 해당 캘린더 → "캘린더 통합" → **"iCal 형식의 비공개 주소"** 를 사용한다.
- OAuth/Google API 없이 `WebParser`로 `.ics`를 받아오기만 하면 되므로 가장 단순함.
- 읽기 전용(일정 추가/수정 불가) — 이 스킨에서는 표시만 하므로 문제없음.
- 알려진 한계: 구글 쪽 iCal 피드는 갱신 반영이 **수 분~수 시간 지연**될 수 있음. README에 명시.
- 여러 캘린더 지원: `ICalUrl1`, `ICalUrl2`, … 최대 3~4개, 캘린더별 색상 점 표시.

#### 보안
- 비공개 주소는 비밀번호와 동급. `Secrets.inc`에만 저장하고 git 제외.
- 주소가 비어 있으면 에러 대신 "Add your iCal URL in Secrets.inc" 안내 문구 표시.
- 로그에 URL 전체가 찍히지 않게 주의 (디버그 출력 시 마스킹).

#### 데이터 흐름
1. `Measure=WebParser`, `URL=#ICalUrl1#`, `RegExp=(?siU)^(.*)$`, `UpdateRate`로 **15분 간격** 갱신, `Download=1`로 `.ics`를 로컬 캐시에 저장 (오프라인 시 마지막 캐시 사용).
2. `FinishAction`에서 Lua(`ICalParser.lua`) 호출 → 파일 읽어서 파싱.
3. Lua가 결과를 변수/미터에 반영 (`SKIN:Bang('!SetOption', ...)`).

#### ICS 파싱 요구사항 (`ICalParser.lua`)
- 라인 unfolding (RFC 5545: 공백/탭으로 시작하는 줄은 이전 줄과 이어붙이기).
- `VEVENT`의 `SUMMARY`, `DTSTART`, `DTEND`, `LOCATION`, `RRULE`, `EXDATE`, `RECURRENCE-ID`, `STATUS` 추출.
- 날짜 형식 3종 처리: `DTSTART;VALUE=DATE:20261117`(종일), `...T090000Z`(UTC), `DTSTART;TZID=Asia/Seoul:...`(로컬).
- 표시는 **Asia/Seoul(로컬 시간)** 기준으로 변환. UTC → 로컬 오프셋은 OS 기준으로 계산.
- `RRULE` 지원 범위: `FREQ=DAILY|WEEKLY|MONTHLY|YEARLY`, `INTERVAL`, `COUNT`, `UNTIL`, `BYDAY`(WEEKLY에서). 그 이상 복잡한 규칙은 무시하고 `TODO`.
- `EXDATE`로 제외된 회차, `RECURRENCE-ID`로 수정된 회차 반영.
- `STATUS:CANCELLED` 제외.
- 텍스트 이스케이프 해제 (`\,` `\;` `\n`).
- 성능: 오늘 기준 **-1개월 ~ +2개월** 범위만 전개.

#### UI
- 상단: `November 2026` + ◀ ▶ 월 이동 버튼 + 클릭 시 오늘로 복귀.
- 7×6 달력 그리드, 요일 헤더 `Mon Tue Wed Thu Fri Sat Sun` (시작 요일 변수 `WeekStart=Mon|Sun`).
- 오늘 날짜: Accent 원형 하이라이트. 이번 달 아닌 날짜: 흐리게.
- 일정 있는 날: 날짜 아래 작은 점 (캘린더별 색).
- 하단: **Upcoming** 리스트 — 오늘부터 다가오는 일정 최대 5개 (`Today 14:00  Team meeting`, 종일 일정은 `All day`).
- 날짜 클릭 시 하단 리스트를 해당 날짜 일정으로 전환 (선택).

### 4.3 System (CPU · RAM)
- CPU: `Measure=CPU` 전체 사용률 %, 우측에 작은 라인 그래프(`Meter=Line`, 최근 60초).
- RAM: `Measure=PhysicalMemory` → 사용량 `9.4 / 16.0 GB` + % + 가로 바(`Meter=Bar`).
- 80% 이상이면 숫자/바 색을 `ColorWarn`으로 (`IfCondition`).
- (선택) CPU 온도/GPU는 외부 툴(HWiNFO) 필요하므로 이번 범위에서 제외.

### 4.4 Network
- 내장 `NetIn` / `NetOut` measure 사용 (`Interface=Best` 기본).
- 표시: `↓ 12.4 MB/s` / `↑ 320 KB/s` — 단위 자동 스케일 (B/KB/MB), bytes 기준 (bits 옵션 변수 `UseBits=0`).
- 하단에 다운/업 겹친 Line 그래프 (Accent / AccentDim 색).
- 오늘 누적 전송량 (`Cumulative=1`) 표시 (선택).
- (선택) 로컬 IP / 외부 IP — 외부 IP는 WebParser로 가져오며 30분 간격.

### 4.5 Music Player (Spotify + Audio Visualizer)

#### 연동 방식 — WebNowPlaying (Redux) 플러그인 + Windows 미디어 세션
- **Spotify 데스크톱 앱**과 연동해야 함.
- 사용할 것: **WebNowPlaying Rainmeter 플러그인 (keifufu 포크, "Redux")**. 최신 버전은 Windows 기본 미디어 API(Native APIs)를 지원해 브라우저 확장이나 Spicetify 없이 데스크톱 Spotify를 읽을 수 있다.
  - 저장소: `github.com/keifufu/WebNowPlaying-Rainmeter` — **최신 릴리스, 옵션 이름, Native API 활성화 방법을 반드시 확인**할 것 (`TODO(verify)`).
  - `.rmskin`에 플러그인 DLL을 포함(`@Vault` 방식)해 설치 시 자동 설치되게.
- 대안(플러그인이 안 될 경우): Windows GSMTC 기반 다른 플러그인(`RainmeterMediaPlayer` 등) — 구현 단계에서 사용자에게 먼저 확인받을 것.
- **Spotify Web API(OAuth)는 사용하지 않는다** (토큰 관리 복잡, 재생 제어는 Premium 필요).
- 앨범 아트가 일부 상황(데스크톱 Spotify)에서 잘리거나 안 나올 수 있다는 보고가 있음 → 아트가 없으면 placeholder 표시.

#### UI 구성 (가로형 카드, 폭 약 340px)
```
┌──────────────────────────────────────┐
│ [Album ]  Song Title (marquee)       │
│ [ Art  ]  Artist · Album             │
│ [ 64px ]  ━━━━━━●──────── 1:24 / 3:51│
│           ⏮   ⏯   ⏭      🔀  🔁      │
│ ▁▂▅▇▅▃▂▁▂▄▆▇▆▄▂▁▂▃▅▆▅▃▂▁  (visualizer)│
└──────────────────────────────────────┘
```
- 제목/아티스트가 길면 스크롤(marquee) 또는 말줄임.
- 진행 바: 클릭/드래그로 탐색(seek) 가능 (`SetPosition`).
- 컨트롤: Previous / PlayPause / Next / Shuffle / Repeat. 재생 상태에 따라 아이콘 전환. 아이콘은 `Shape` 미터로 그려 이미지 의존 최소화.
- 볼륨: 마우스 휠로 조절 (선택).
- 재생 중인 것이 없으면 "Nothing playing" + 비주얼라이저 정지/숨김.
- 앨범 아트 클릭 시 Spotify 창 활성화.

#### 오디오 비주얼라이저 — 내장 `AudioLevel` 플러그인
- `Plugin=AudioLevel`, `Port=Output` (기본 출력 장치 loopback 캡처 → Spotify 소리를 그대로 분석).
  - 이 방식은 Spotify만이 아니라 **시스템 전체 출력**을 분석함. README에 명시.
- FFT 설정 (초기값, 튜닝 가능하게 변수화):
  - `Bands=24` (변수 `VisBands`), `FFTSize=1024`, `FFTOverlap=512`, `FreqMin=40`, `FreqMax=16000`, `Sensitivity=35`
  - 상승/하강 스무딩: `FFTAttack`, `FFTDecay` 사용 (예: 15 / 250 ms).
- 렌더링: 둥근 막대(Bar 미터 or Shape) N개, 색은 Accent → 위로 갈수록 AccentDim 그라데이션.
- 갱신 주기: 비주얼라이저 부분만 `Update=25`~`33` (30~40fps). 음악 메타데이터는 별도 measure `UpdateDivider`로 1초 간격 유지 → CPU 부하 최소화.
  - 가능하면 비주얼라이저를 **별도 스킨(Music\Visualizer.ini)** 으로 분리해 메인 카드는 Update=1000 유지. 둘은 같은 위치에 겹치게 배치.
- 재생 정지(`State != Playing`) 시 `!DisableMeasureGroup`으로 비주얼라이저 measure 비활성화 → 유휴 CPU 사용 0에 가깝게.
- 막대 미터는 반복 작업이므로 **Lua 또는 생성 스크립트로 자동 생성**하거나, 개수 변경 시 수동 편집이 필요 없도록 설계.

---

## 5. 성능 목표
- 모든 위젯 켠 상태에서 음악 정지 시 Rainmeter CPU 사용률 **< 1%**, 재생+비주얼라이저 시 **< 3%** (일반 데스크톱 기준).
- WebParser 요청은 15분 이상 간격, 실패 시 지수 백오프 없이도 최소한 로그 스팸이 없게.

## 6. 에러/엣지 케이스
- 인터넷 끊김 → 캘린더는 캐시 데이터 + 작은 "offline" 표시.
- iCal URL 미설정/잘못됨 → 안내 문구, 스킨 크래시 없음.
- Spotify 미실행 → 플레이어 placeholder, 컨트롤 비활성.
- 다중 모니터·DPI 125/150% 에서 텍스트 잘림 없음.
- 네트워크 어댑터 변경(와이파이↔유선) 시 자동 추적.

## 7. 구현 순서 (마일스톤)
1. `@Resources` 디자인 시스템 + 빈 배경 카드 스킨 1개로 스타일 검증
2. Clock
3. System (CPU/RAM)
4. Network
5. Music Player (메타데이터·컨트롤) → 사용자 확인
6. Audio Visualizer
7. Calendar 그리드 (로컬 데이터만)
8. iCal 연동 + 파서 + Upcoming 리스트
9. 테마 전환/Settings 스킨 (선택)
10. README 작성 + `.rmskin` 패키징

각 단계 완료 시: 스크린샷으로 확인할 포인트와 Rainmeter 로그 확인 방법을 사용자에게 알려줄 것.

## 8. README에 포함할 것
- 설치 방법 (`.rmskin` 더블클릭)
- 구글 캘린더 iCal 비공개 주소 얻는 법 + `Secrets.inc`에 넣는 법 + "이 주소는 절대 공유하지 말 것"
- WebNowPlaying 설정 (Native API / Spotify 데스크톱)
- 비주얼라이저가 시스템 전체 소리를 분석한다는 점
- 테마 색 바꾸는 법 (`Variables.inc` 또는 Settings 스킨)
- 알려진 한계: 캘린더 반영 지연, 복잡한 RRULE 미지원

## 9. 범위 밖 (이번에 하지 않음)
- 캘린더 일정 생성/수정 (iCal은 읽기 전용)
- Spotify Web API / 좋아요·플레이리스트 제어
- 날씨, 디스크, GPU, 온도
