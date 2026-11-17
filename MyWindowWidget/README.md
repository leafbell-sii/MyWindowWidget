# MyWindowWidget

반투명 다크 브라운 톤의 미니멀 Rainmeter 위젯 모음입니다.

| 위젯 | 내용 |
|---|---|
| **Clock** | 큰 `HH:mm` 시계, 초, 영어 날짜 (`Tuesday, November 17`) |
| **System** | CPU 사용률 + 최근 60초 그래프, RAM 사용량(GB·%) + 바. 80% 이상이면 경고색 |
| **Network** | 다운로드/업로드 속도(단위 자동), 그래프, 오늘 누적 전송량 |
| **Music** | Spotify 지금 재생 중: 앨범 아트, 제목/아티스트, 진행 바, 재생 컨트롤 |
| **Calendar** | 구글 캘린더 월 달력 + 다가오는 일정 5개 |
| **Settings** | 테마·불투명도·시계 형식·주 시작 요일을 클릭으로 바꾸는 설정 카드 |

모든 위젯은 따로 켜고 끄고 옮길 수 있습니다.

- 요구 사항: Windows 10/11, Rainmeter 4.5 이상

---

## 설치

1. `MyWindowWidget_<버전>.rmskin`을 더블클릭합니다.
2. Rainmeter 설치 창에서 **Install**을 누릅니다.
   - 위젯이 쓰는 **WebNowPlaying 플러그인**도 함께 설치됩니다.
   - 이전 버전을 다시 설치할 때 기존 폴더는 `Skins\@Backup`으로 옮겨집니다.
   - 내가 넣어 둔 값(iCal 주소, `Variables.inc` 설정)은 새 버전에 그대로 옮겨집니다.
3. 설치가 끝나면 Clock이 바로 뜹니다. 나머지 위젯은 이렇게 켭니다:
   - 작업 표시줄 트레이의 Rainmeter 아이콘 → **MyWindowWidget** → 원하는 위젯(`System.ini` 등) 클릭
   - 또는 Rainmeter **관리(Manage)** 창 → `MyWindowWidget` 폴더 → 위젯 선택 → **Load**

위젯은 드래그해서 옮길 수 있고, 위치는 자동 저장됩니다.

---

## 구글 캘린더 연결 (Calendar)

Calendar는 구글 캘린더의 **"iCal 형식의 비공개 주소"**를 읽어 표시합니다. 읽기 전용이라 위젯에서 일정을 추가하거나 수정할 수는 없습니다.

### 1. 주소 복사

1. 웹에서 [Google Calendar](https://calendar.google.com) → 오른쪽 위 ⚙ **설정**
2. 왼쪽 **내 캘린더의 설정**에서 표시할 캘린더 클릭
3. **캘린더 통합** → **iCal 형식의 비공개 주소** 복사
   - 바로 위의 "iCal 형식의 공개 주소"가 아닙니다. 비공개 주소에는 보통 `private-`가 들어 있습니다.

### 2. `Secrets.inc`에 붙여넣기

`문서\Rainmeter\Skins\MyWindowWidget\@Resources\Secrets.inc`를 메모장으로 열고 `=` 뒤에 붙여넣습니다.

```ini
[Variables]
ICalUrl1=https://calendar.google.com/calendar/ical/.../basic.ics
ICalUrl2=
ICalUrl3=
ICalUrl4=
```

- 캘린더는 최대 4개까지 넣을 수 있고, 캘린더마다 점 색이 다릅니다.
- 쓰지 않는 칸은 비워 두세요. 빈 칸은 아예 요청하지 않습니다.

저장한 뒤 Calendar 위젯을 우클릭 → **스킨 새로고침(Refresh skin)** 하면 바로 반영됩니다.

> ⚠️ **이 주소는 비밀번호와 같습니다.** 주소를 아는 사람은 누구나 캘린더 내용을 볼 수 있습니다. 스크린샷, 채팅, 깃허브 등 어디에도 올리지 마세요.
> 실수로 공개됐다면 같은 화면의 **재설정**으로 주소를 바꾸고 새 주소를 다시 넣으면 됩니다.

### 사용법

- **월 제목** 클릭: 오늘로 돌아가기
- **‹ ›**: 이전 / 다음 달
- **날짜** 클릭: 아래 목록이 그날 일정으로 바뀜. 같은 날짜나 **UPCOMING** 제목을 다시 누르면 원래대로 돌아갑니다.
- 일정은 15분마다 다시 받아옵니다(`Variables.inc`의 `ICalRefreshSeconds`).
- 인터넷이 끊기면 마지막으로 받은 일정을 보여주고, 목록 오른쪽 위에 `offline`이 표시됩니다.
  - 주소가 틀렸거나 재설정된 경우에도 `offline`이 표시됩니다.

---

## 음악 (Music) — Spotify

**WebNowPlaying** 플러그인(v3)이 Windows의 미디어 정보를 읽기 때문에 **데스크톱 Spotify 앱만 켜져 있으면 별도 설정이 필요 없습니다.** 브라우저 확장이나 Spicetify를 설치할 필요가 없습니다.

- **앨범 아트** 클릭: Spotify 열기
- **진행 바** 클릭: 그 위치로 이동(탐색)
- 이전 / 재생·일시정지 / 다음 / 셔플 / 반복 버튼
  - 셔플·반복은 켜지면 앰버색이 되고, 한 곡 반복이면 아이콘에 `1`이 표시됩니다.
- 아무것도 재생하지 않으면 "Nothing playing"과 흐린 컨트롤이 표시됩니다.
- 카드 위 마우스 휠로 볼륨 조절을 시도하지만, 대부분의 데스크톱 플레이어(Spotify 포함)는 이 기능을 지원하지 않습니다.

Spotify 외에 Windows 미디어 정보를 제공하는 다른 플레이어도 표시될 수 있습니다.

---

## 설정 바꾸기

### Settings 위젯 (클릭으로)

**Settings** 위젯을 켜면 아래 항목을 클릭으로 바꿀 수 있고, 모든 MyWindowWidget 위젯에 바로 반영됩니다.

- **Theme**: Brown / Slate / Forest / Mono
- **Opacity**: 카드 불투명도 70% / 85% / 100%
- **24-hour clock**: 24시간제 켜기·끄기
- **Show seconds**: 초 표시 켜기·끄기
- **Week starts on**: 달력 시작 요일 Mon / Sun

선택한 값은 `@Resources\Variables.inc`에 저장됩니다.

### 직접 고치기

모든 설정은 `@Resources\Variables.inc`에 있습니다. 메모장으로 고친 뒤 위젯을 새로고침하세요. 전체를 한 번에 새로고침하려면 Rainmeter 관리 창 → **모두 새로고침(Refresh all)**을 누르면 됩니다.

| 변수 | 기본값 | 설명 |
|---|---|---|
| `Use24h` | `1` | `0` = 12시간제(AM/PM) |
| `ShowSeconds` | `1` | `0` = 초 숨김 |
| `UseBits` | `0` | `1` = 네트워크 속도를 비트(Mb/s)로 |
| `WarnThreshold` | `80` | CPU/RAM 경고색 기준(%) |
| `WeekStart` | `Mon` | `Sun` = 일요일부터 시작 |
| `ICalRefreshSeconds` | `900` | 캘린더 갱신 간격(초) |
| `Theme` | `Brown` | 테마 파일 이름(`Themes\` 안) |
| `BgAlpha` | `217` | 카드 불투명도 0~255 (178 = 70%, 217 = 85%, 255 = 100%) |
| `SuiteScale` | `1` | 전체 크기 배율(예: `1.15`). Windows 배율(125% 등)은 Rainmeter가 이미 반영하므로 보통은 그대로 두세요. |
| `CalendarScale` | `1.5` | Calendar만 다른 위젯보다 몇 배 크게 그릴지 |
| `CompactWidth` / `CompactHeight` | `300` / `138` | System·Network 카드 크기(4장을 쌓으면 Calendar 높이와 비슷) |

### 테마 색 바꾸기

색은 `@Resources\Themes\<테마>.inc`에 있습니다. 형식은 `R,G,B,A`이고, A는 불투명도입니다(0 = 투명, 255 = 불투명).
카드 배경만 예외로 `R,G,B`만 적습니다. 불투명도는 모든 테마에 공통으로 `BgAlpha`가 정합니다.

```ini
; 카드 배경색 (R,G,B)
ColorBgRGB=32,22,17
; 포인트 색 (오늘 날짜, 그래프, 버튼)
ColorAccent=214,154,96,255
; 캘린더별 점 색
ColorCal1=214,154,96,255
```

새 테마를 만들려면:
1. `Brown.inc`를 복사해 `Themes\MyTheme.inc`처럼 저장하고 색을 바꿉니다.
2. `Variables.inc`의 `ThemeList`에 이름을 추가합니다.
   - 예: `ThemeList=Brown|Slate|Forest|MyTheme`
   - Settings에는 최대 4개까지 표시됩니다.
3. Settings 위젯에서 고르거나, `Theme=MyTheme`으로 직접 바꿉니다.

---

## 알려진 한계

- **캘린더 반영 지연**: 구글의 iCal 피드 자체가 몇 분에서 몇 시간 늦게 갱신될 수 있습니다. 방금 추가한 일정이 바로 안 보일 수 있습니다.
- **지원하는 반복 규칙**: 매일 / 매주(요일 지정 포함) / 매월(같은 날짜) / 매년, 간격·횟수·종료일, 제외된 날짜와 개별 수정된 회차.
  - **"매월 둘째 화요일"** 같은 규칙은 아직 지원하지 않아 **첫 회차만** 표시됩니다.
- **표시 범위**: 반복 일정은 오늘 기준 1개월 전부터 2개월 뒤까지만 펼칩니다. 그보다 먼 달로 넘기면 반복 일정이 보이지 않습니다.
- **시간대**: 일정은 한국 시간(Asia/Seoul) 기준으로 표시합니다. 다른 시간대를 지정해 만든 일정은 시간이 어긋날 수 있습니다(UTC 일정은 정상 변환됨).
- **음악 탐색**: 진행 바는 클릭으로만 이동하고, 드래그는 안 됩니다(Rainmeter에 마우스 이동 이벤트가 없음).
- **긴 제목**: 길면 `…`으로 잘립니다(스크롤 없음).

---

## 문제 해결 — 로그 확인

위젯이 이상하면 Rainmeter 로그를 확인하세요.

1. 트레이의 Rainmeter 아이콘 우클릭 → **정보(About)** → **로그(Log)** 탭
2. 출처가 `MyWindowWidget\...`인 **오류/경고** 줄을 찾습니다.

로그에는 iCal 주소가 기록되지 않습니다. 연결에 실패하면 `[MeasureICal1] (Fetch error) ...`처럼 원인만 남습니다.

---

## 개발 / 패키지 빌드

저장소 구조:

```
MyWindowWidget/            스킨 폴더 (이 README 포함)
  @Resources/     Variables.inc, Styles.inc, Themes/, Scripts/, Secrets*.inc
vendor/           WebNowPlaying DLL(32/64bit) + LICENSE + 출처/해시
tools/            build-rmskin.ps1
```

- **개발 중 실시간 반영**: 스킨 폴더에 저장소를 junction으로 연결하면, 파일을 고치고 새로고침만 하면 됩니다.
  ```bat
  mklink /J "%USERPROFILE%\Documents\Rainmeter\Skins\MyWindowWidget" "<저장소>\MyWindowWidget"
  ```
  - ⚠️ 이렇게 연결된 PC에서는 `.rmskin`을 **설치하지 마세요.** 설치기가 기존 폴더(= junction)를 `@Backup`으로 옮겨 버립니다.
  - Settings 위젯에서 값을 바꾸면 저장소의 `Variables.inc`가 직접 수정됩니다. 커밋하기 전에 diff를 확인하세요.
- **패키지 빌드**: 아래 명령으로 `dist\MyWindowWidget_0.1.0.rmskin`이 만들어집니다.
  ```bat
  powershell -ExecutionPolicy Bypass -File tools\build-rmskin.ps1 -Version 0.1.0
  ```
  - 실제 `Secrets.inc`, 캐시, 받은 캘린더 파일은 패키지에 들어가지 않습니다. 대신 빈 `Secrets.inc`가 들어갑니다.
- **인코딩**: `Scripts\Calendar.lua`는 일부러 **UTF-16 LE(BOM)**로 저장합니다.
  - 이렇게 해야 Rainmeter가 유니코드 모드로 실행해 일정 제목의 이모지·다국어가 깨지지 않습니다.
  - git에는 `.gitattributes`로 UTF-8로 저장됩니다.
  - 다른 `.ini`/`.lua` 파일은 ASCII만 씁니다.

---

## 크레딧

- [WebNowPlaying-Rainmeter](https://github.com/keifufu/WebNowPlaying-Rainmeter) © keifufu — MIT License. 전문은 패키지에 포함된 `@Resources\Licenses\WebNowPlaying.txt`에 있습니다.
- MyWindowWidget: MIT License © 2026 leafbell-sii. 저장소 루트의 `LICENSE`, 패키지에서는 `@Resources\Licenses\MyWindowWidget.txt`에 있습니다.
