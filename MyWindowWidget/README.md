# MyWindowWidget

반투명 다크 브라운 톤의 미니멀 Rainmeter 위젯 모음입니다.

| 위젯 | 내용 |
|---|---|
| **Clock** | 큰 `HH:mm` 시계, 초, 영어 날짜 (`Tuesday, November 17`) |
| **System** | CPU 사용률 + 최근 60초 그래프, RAM 사용량(GB·%) + 바. 80% 이상이면 경고색 |
| **Network** | 다운로드/업로드 속도(단위 자동), 그래프, 오늘 누적 전송량 |
| **Music** | Spotify 지금 재생 중: 앨범 아트, 제목/아티스트, 진행 바, 재생 컨트롤 |
| **Calendar** | 구글 캘린더 월 달력 + 다가오는 일정 5개 |
| **Tasks** | 구글 할 일(Google Tasks) 목록. 마감일 순 정렬, 위젯에서 바로 추가·완료. 목록 3개까지 한 카드에 나눠 표시 |
| **Settings** | 테마·불투명도·시계 형식·주 시작 요일을 클릭으로 바꾸는 설정 카드. 제목줄만 남기고 접을 수 있음 |

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

## 구글 할 일 연결 (Tasks)

Tasks 카드는 Google Tasks의 할 일 목록을 보여주고, 카드에서 바로 **추가**하고 **완료**할 수 있습니다.
카드는 하나(`Tasks`)이고, 높이는 Calendar 카드와 같습니다. 내 목록을 모두 이 카드에 나눠서 보여줍니다.

> **API 키로는 연결할 수 없습니다.** Google Tasks API는 개인 데이터라 OAuth 2.0 로그인만 받습니다.
> 그래서 아래처럼 **처음 한 번만** 내 구글 계정으로 로그인하는 과정이 필요합니다. 이 과정은 직접 해야 합니다.

### 1. Google Cloud에서 OAuth 클라이언트 만들기 (한 번만)

1. [Google Cloud Console](https://console.cloud.google.com/)에 로그인하고, 위쪽 프로젝트 선택 → **새 프로젝트**(이름 예: `MyWindowWidget`).
2. **API 및 서비스 → 라이브러리**에서 **Google Tasks API**를 찾아 **사용**을 누릅니다.
3. **Google Auth Platform**(이전 이름: OAuth 동의 화면)에서 앱 정보를 만듭니다.
   - 사용자 유형: **외부(External)**, 앱 이름·이메일은 아무렇게나(나만 씀).
   - **대상(Audience)**에서 **앱 게시(Publish app)** 를 눌러 상태를 **프로덕션(In production)** 으로 바꿉니다.
     - "테스트(Testing)" 상태로 두면 **7일마다 로그인이 만료**됩니다(구글 정책).
     - 검수(verification)는 받지 않아도 됩니다. 로그인할 때 "확인되지 않은 앱" 경고가 한 번 뜰 뿐입니다.
4. **클라이언트(Clients) → 클라이언트 만들기** → 애플리케이션 유형 **데스크톱 앱(Desktop app)** → 만들기.
5. 만든 클라이언트의 **JSON 다운로드**를 누릅니다(`client_secret_....json`).

### 2. 로그인 (한 번만)

PowerShell 창을 열고 아래를 실행합니다(JSON 경로는 받은 파일로 바꿔 주세요).

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\Documents\Rainmeter\Skins\MyWindowWidget\@Resources\Scripts\GTasks.ps1" -Action setup -ClientSecretFile "$env:USERPROFILE\Downloads\client_secret_XXXX.json"
```

1. 브라우저에 구글 로그인 창이 뜨면 할 일을 쓰는 계정으로 로그인합니다.
2. "Google에서 확인하지 않은 앱" 화면이 나오면 **고급 → (앱 이름)(으)로 이동** → **계속**을 누릅니다. 내가 만든 앱이라 괜찮습니다.
3. 권한 요청(할 일 보기·수정)을 **허용**하면, 콘솔에 `Connected.`와 내 목록 이름이 표시됩니다.
4. 이제 **다운로드한 JSON 파일은 지워도 됩니다.**

로그인 정보(클라이언트 ID·비밀, refresh token)는 **Windows DPAPI로 암호화**해서 `%LOCALAPPDATA%\MyWindowWidget\GoogleTasks\`에 저장합니다.
현재 Windows 사용자만 풀 수 있고, 스킨 폴더·패키지·git에는 들어가지 않습니다.

**연결 해제**: 아래를 실행하면 구글에서 권한을 취소하고 저장된 정보와 캐시를 지웁니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\Documents\Rainmeter\Skins\MyWindowWidget\@Resources\Scripts\GTasks.ps1" -Action signout
```

### 사용법

- 카드 켜기: Rainmeter 관리 창 → `MyWindowWidget\Tasks` → `Tasks.ini` → **Load**
- 목록 수에 따라 카드를 같은 크기의 구역으로 나눕니다.
  - 목록 1개: 카드 전체 / 2개: 2등분 / 3개: 3등분
  - 4개 이상: 3등분한 채로 위쪽 **‹ ›**로 넘겨 봅니다(`1/2`처럼 쪽 번호 표시). 마지막 쪽은 마지막 목록 3개를 보여줍니다.
- 할 일은 **마감일 순**(빠른 날짜가 위, 마감일 없는 할 일은 맨 아래)입니다. 하위 할 일은 상위 할 일 아래에 들여써서, 같은 방식으로 정렬합니다.
- **TASKS** 제목 클릭: 지금 동기화
- **○** 클릭: 완료 처리(마우스를 올리면 체크 표시)
- 목록 이름 오른쪽 **+**: 그 목록에 추가. 입력창에 제목을 쓰고 **Enter**(취소는 Esc 또는 바깥 클릭). 마감일이 없으니 마감일 있는 할 일 다음에 표시됩니다.
- 마감일은 오른쪽에 `Today`, `Tomorrow`, `Nov 20`처럼 표시되고, 지난 날짜는 경고색입니다.
- 구역에 다 들어가지 않으면 목록 이름 옆에 `+N more`가 표시됩니다.
- 5분마다 다시 받아옵니다(`Variables.inc`의 `TasksRefreshSeconds`).
- 인터넷이 끊기면 마지막 목록을 그대로 보여주고 위쪽에 `Offline`이 표시됩니다.
- 카드에 "Sign-in expired"가 뜨면 위의 **2. 로그인**을 다시 실행하세요(동의 화면이 "테스트" 상태였거나, 구글 계정에서 권한을 취소한 경우).

---

## 설정 바꾸기

### Settings 위젯 (클릭으로)

**Settings** 위젯을 켜면 아래 항목을 클릭으로 바꿀 수 있고, 모든 MyWindowWidget 위젯에 바로 반영됩니다.

- **Theme**: Brown / Slate / Forest / Mono / Christmas / Cafe
  - **Christmas**, **Cafe**는 색뿐 아니라 폰트와 카드 배경 그림까지 바꾸는 컨셉 테마입니다(아래 "컨셉 테마").
- **Opacity**: 카드 불투명도 70% / 85% / 100%
- **24-hour clock**: 24시간제 켜기·끄기
- **Show seconds**: 초 표시 켜기·끄기
- **Week starts on**: 달력 시작 요일 Mon / Sun
- 오른쪽 위 **⌃ / ⌄**(또는 SETTINGS 제목) 클릭: 카드를 접어 제목줄만 남기거나 다시 펼칩니다.

선택한 값(접힘 상태 `SettingsCollapsed` 포함)은 `@Resources\Variables.inc`에 저장됩니다.

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
| `SuiteScale` | `1` | 전체 크기 배율(예: `1.15`). 보통은 그대로 두세요. 단, 아래 "화면 배율이 100%가 아닐 때"처럼 DPI 재정의를 켰다면 Windows 배율 값(125% → `1.25`)으로 맞춥니다. |
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
   - Settings에는 최대 8개(4개씩 2줄)까지 표시됩니다.
3. Settings 위젯에서 고르거나, `Theme=MyTheme`으로 직접 바꿉니다.

### 컨셉 테마 (폰트 + 카드 배경)

테마 파일은 색 외에 폰트와 카드 그림도 정할 수 있습니다. 정하지 않은 값은 `Variables.inc`의 "Theme defaults"(Segoe UI, 그림 없음)를 씁니다.

| 테마 | 숫자·시계 폰트 | 본문 폰트 | 카드 배경 |
|---|---|---|---|
| Christmas | Emilys Candy | Jua (한글 지원) | 짙은 초록 + 은은한 눈송이, 위쪽에 꼬마전구 줄 |
| Cafe | Gaegu Bold | Gaegu (한글 지원, 손글씨) | 라떼색 종이 결 + 커피잔 자국·원두, 위쪽에 줄무늬 차양 |

```ini
; 폰트: @Resources\Fonts 안의 .ttf/.otf는 자동으로 로드됩니다. 파일 이름이 아닌 글꼴 이름을 씁니다.
FontFace=Jua
FontFaceNum=Emilys Candy
; 글자가 작게 그려지는 폰트면 전체 글자 크기 배율
FontScale=1
; 카드 그림: 카드 전체에 타일로 까는 반투명 텍스처 + 위쪽 가장자리 장식 띠
CardTexture=#@#Images\Christmas\Texture.png
CardTrim=#@#Images\Christmas\Trim.png
CardTrimH=16
```

- 그림은 카드의 둥근 모서리 안쪽으로 잘려 그려지고, **Opacity** 설정을 따라 함께 투명해집니다.
- 그림은 `tools/dev/make-concept-art.py`로 생성했습니다(Pillow 필요). 색이나 무늬를 바꾸려면 스크립트를 고쳐 다시 실행하세요.
- 폰트를 바꾸면 시계의 초·AM/PM 위치가 어긋날 수 있습니다. `tools/dev/font-metrics.py <폰트파일>`이 출력하는 `FontCapTop`, `FontAscent` 등의 값을 테마 파일에 넣으면 맞춰집니다.

---

## 알려진 한계

- **캘린더 반영 지연**: 구글의 iCal 피드 자체가 몇 분에서 몇 시간 늦게 갱신될 수 있습니다. 방금 추가한 일정이 바로 안 보일 수 있습니다.
- **지원하는 반복 규칙**: 매일 / 매주(요일 지정 포함) / 매월(같은 날짜) / 매년, 간격·횟수·종료일, 제외된 날짜와 개별 수정된 회차.
  - **"매월 둘째 화요일"** 같은 규칙은 아직 지원하지 않아 **첫 회차만** 표시됩니다.
- **표시 범위**: 반복 일정은 오늘 기준 1개월 전부터 2개월 뒤까지만 펼칩니다. 그보다 먼 달로 넘기면 반복 일정이 보이지 않습니다.
- **시간대**: 일정은 한국 시간(Asia/Seoul) 기준으로 표시합니다. 다른 시간대를 지정해 만든 일정은 시간이 어긋날 수 있습니다(UTC 일정은 정상 변환됨).
- **음악 탐색**: 진행 바는 클릭으로만 이동하고, 드래그는 안 됩니다(Rainmeter에 마우스 이동 이벤트가 없음).
- **긴 제목**: 길면 `…`으로 잘립니다(스크롤 없음).
- **할 일(Tasks)**: 추가와 완료만 됩니다. 제목·마감일 수정, 삭제, 메모 보기, 완료 취소는 구글 앱에서 하세요. 완료한 할 일은 표시하지 않습니다.
- **Tasks 표시 줄 수**: 카드 높이가 Calendar에 맞춰 고정이라, 한 구역에 들어가지 않는 할 일은 `+N more`로만 표시됩니다(스크롤 없음).

### 화면 배율이 100%가 아닐 때 (위젯이 흐릿함)

Rainmeter 4.5는 DPI를 인식하지 못하는 앱이라, Windows 배율이 125%·150%이면 Windows가 위젯을 **그림째로 늘려서** 글자와 선이 흐려집니다. 위젯 자체의 안티앨리어싱은 이미 켜져 있으니, 아래처럼 Rainmeter가 실제 해상도로 그리게 하면 선명해집니다.

1. Rainmeter를 종료합니다(트레이 아이콘 우클릭 → **Exit**).
2. `C:\Program Files\Rainmeter\Rainmeter.exe` 우클릭 → **속성** → **호환성** → **높은 DPI 설정 변경**
3. **높은 DPI 조정 동작을 재정의합니다** 체크 → 수행 주체: **애플리케이션** → 확인
4. `Variables.inc`의 `SuiteScale`을 Windows 배율 값으로 바꿉니다(125% → `1.25`, 150% → `1.5`).
5. Rainmeter를 다시 실행합니다. 위젯 위치 좌표도 실제 픽셀 기준이 되므로 겹치면 드래그로 다시 놓습니다.

> Windows 배율을 바꾸면 `SuiteScale`도 함께 바꿔야 합니다.

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
  @Resources/     Variables.inc, Styles.inc, CardArt.inc, Themes/, Scripts/, Secrets*.inc
                  Fonts/ (번들 폰트 + 라이선스), Images/ (컨셉 테마 카드 그림)
vendor/           WebNowPlaying DLL(32/64bit) + LICENSE + 출처/해시
tools/            build-rmskin.ps1, dev/ (로그·스크린샷·폰트 메트릭·카드 그림 생성)
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
- 폰트: [Jua](https://fonts.google.com/specimen/Jua), [Gaegu](https://fonts.google.com/specimen/Gaegu), [Emilys Candy](https://fonts.google.com/specimen/Emilys+Candy) — SIL Open Font License 1.1. 전문은 `@Resources\Fonts\*-OFL.txt`에 있습니다.
- MyWindowWidget: MIT License © 2026 leafbell-sii. 저장소 루트의 `LICENSE`, 패키지에서는 `@Resources\Licenses\MyWindowWidget.txt`에 있습니다.
