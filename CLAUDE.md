# CLAUDE.md — MyWindowWidget 작업 인수인계

Rainmeter 위젯 모음 **MyWindowWidget**의 저장소입니다. 원래 명세(Umber 스위트)의 마일스톤은 모두 끝났고, 이 문서가 그 명세를 대신합니다.
사용자용 설명은 [MyWindowWidget/README.md](MyWindowWidget/README.md)에 있습니다.

## 작업 원칙

- **답변은 한국어로.** 코드, 주석, 위젯 UI 문구는 영어로 씁니다.
- **디자인 값 하드코딩 금지.**
  - 색은 `@Resources/Themes/*.inc`, 크기·간격·폰트·동작 설정은 `@Resources/Variables.inc`에서만 가져옵니다.
  - 크기는 `(N*#Scale#)` 형태로 씁니다.
- **외부 플러그인은 지금 WebNowPlaying 하나만** 씁니다. 나머지는 내장 measure/plugin(+Lua, RunCommand로 PowerShell)으로 구현합니다.
  - 공식 문서·소스 검색을 포함한 빠른 방법이 모두 실패했을 때만, **사용자에게 그 외부 플러그인을 써도 되는지 먼저 물어봅니다.**
  - 허락을 받았더라도 **사용하기 직전에 반드시 백신 검사**(예: Microsoft Defender `MpCmdRun.exe -Scan -ScanType 3 -File <경로>`)와 출처·해시 확인을 합니다. 결과는 `vendor/<플러그인>/SOURCE.md`에 남깁니다.
- 플러그인·API 옵션은 학습 지식에 기대지 말고 공식 문서나 소스로 확인합니다. 확인하지 못한 부분은 `TODO(verify)`로 남깁니다.
- **변경 후에는 반드시 확인합니다.**
  - Rainmeter 로그에 `MyWindowWidget\...` 오류·경고가 없어야 합니다.
  - 화면은 스크린샷으로 확인합니다. 방법은 아래 "개발 루프"에 있습니다.
- **비밀값 취급**
  - 실제 iCal 주소는 `@Resources/Secrets.inc`에만 둡니다(git 제외).
  - 이 파일 내용이나 주소를 출력하거나 로그에 남기지 않습니다.

## 구조

```
MyWindowWidget/              스킨 루트 (= Rainmeter config 루트, 패키지에 그대로 들어감)
  @Resources/
    Variables.inc            공용 설정. Theme/BgAlpha/Use24h 등. Clock의 설정 화면이 여기에 씀
    Styles.inc               공용 MeterStyle (StyleCard, StyleTitle, StyleValue ...)
    Themes/*.inc             테마 (ColorBgRGB + 나머지 R,G,B,A). ThemeList에 등록
                             Christmas/Cafe는 폰트·카드 그림까지 정하는 컨셉 테마
    CardArt.inc              카드 그림 미터 (각 스킨 [MeterBg]에서 @Include)
    Fonts/                   번들 폰트 (Jua, Gaegu, Emilys Candy) + *-OFL.txt
    Images/<테마>/           Texture.png, Trim.png (make-concept-art.py로 생성)
    Secrets.inc              실제 iCal 주소 (git 제외) / Secrets.example.inc 템플릿
    Cache/                   런타임 캐시 (calN.ics, NetToday.txt, tasks.*, weather.txt,
                             gpu.txt/gpu.alive, clock.view, music.view, *.zpos) - git 제외
    Scripts/                 Lua: Calendar, ICalParser, Music(접기/펼치기), Network, Settings(Clock 화면 전환+설정),
                             Weather, System(GPU 값+드라이브 줄), Tasks, ZOrder(펼친 카드 Topmost)
                             PowerShell(RunCommand로 실행): GTasks.ps1 (Google Tasks OAuth/API),
                             Weather.ps1 (위치·지명·날씨), GpuLoad.ps1 (GPU 사용률 상주 샘플러)
  Clock/ System/ Network/ Music/ Calendar/ Tasks/   스킨 (.ini 하나씩)
vendor/WebNowPlaying/        플러그인 DLL 32/64bit (v3.0.0-alpha.5, sha256은 SOURCE.md)
tools/build-rmskin.ps1       dist/MyWindowWidget_<버전>.rmskin 생성
tools/dev/                   read-rainmeter-log.ps1, screenshot-skins.ps1,
                             font-metrics.py, make-concept-art.py (Pillow/fontTools 필요)
```

- 모든 스킨은 `Group=MyWindowWidget`입니다. Clock의 설정 화면은 값을 바꾼 뒤 `!RefreshGroup MyWindowWidget`으로 전체를 새로고침합니다.
- 카드 배경은 각 스킨의 `[Variables]`에 `CardW` / `CardH`를 정하고 `MeterStyle=StyleCard`를 씁니다.
  - `CardH`는 보통 `([마지막미터:YH]+#Pad#)` 형태입니다.
  - `[MeterBg]`에 `@IncludeCardArt=#@#CardArt.inc`가 있어 테마 그림(텍스처, 위쪽 장식 띠)이 카드 색 위에 그려집니다. 새 스킨도 똑같이 넣습니다.
- **테마가 덮어쓰는 값**(폰트, `FontScale`, 폰트 메트릭, `CardTexture`/`CardTrim`)의 기본값은 `Variables.inc`에서 `@IncludeTheme` **앞**에 둡니다. 뒤에 두면 기본값이 테마 값을 이깁니다.
- **글자 위치 맞춤은 폰트 메트릭 변수로** 합니다(`FontCapTop`, `FontAscent`, `FontCapTopNum`, `FontAscentNum`, `FontDescentNum`). Segoe UI 전용 상수(1.44, 0.30 등)를 새로 쓰지 않습니다. 값은 `tools/dev/font-metrics.py`로 구합니다.
  - 글자 폭에 맞춘 고정 칸(`WhenW`, `RamDetailW`, `UnitW`)은 `*#FontScale#`을 곱합니다.

## 개발 루프 (이 PC 기준)

- **연결**: `문서\Rainmeter\Skins\MyWindowWidget`이 저장소의 `MyWindowWidget/`를 가리키는 **junction**입니다.
  - 파일을 고친 뒤 `Rainmeter.exe !Refresh "MyWindowWidget\Clock"`이나 `!RefreshGroup MyWindowWidget`을 실행하면 바로 반영됩니다.
  - 새 config 폴더를 추가했으면 먼저 `!RefreshApp`을 실행합니다.
  - ⚠️ `!RefreshApp`은 Music(WebNowPlaying v3 alpha)이 켜져 있으면 Rainmeter를 죽일 수 있습니다(2026-11-17, 오류 모듈 `WebNowPlaying.DLL_unloaded`). 죽으면 `Start-Process "$env:ProgramFiles\Rainmeter\Rainmeter.exe"`로 다시 띄웁니다.
  - Rainmeter가 조용히 꺼졌는지는 `Get-Process Rainmeter`와 이벤트 로그(Application, Windows Error Reporting)로 확인합니다. 로그 리더는 프로세스가 없으면 `Get-Process` 오류를 냅니다.
- **로그 확인**: `tools/dev/read-rainmeter-log.ps1 -Since HH:mm:ss`
  - About 창의 리스트뷰를 직접 읽습니다. 파일 로깅을 켤 필요가 없습니다.
- **스크린샷**: `tools/dev/screenshot-skins.ps1 -Skin Calendar -Out <png>`
  - Claude 앱 창이 바탕화면을 가리므로 잠깐 `!ZPos 2`로 올렸다가 되돌립니다.
  - 결과가 검은 화면이면 화면이 잠긴 상태입니다.
- **스킨 내부 값 확인**:
  ```
  Rainmeter.exe !CommandMeasure <ScriptMeasure> "SKIN:Bang('!Log', ...)" "<config>"
  ```
  - Lua로 미터 옵션이나 measure 값을 로그에 찍어 확인합니다.
  - PowerShell에서는 `Start-Process -ArgumentList '...'`로 인용부호를 통째로 넘겨야 안 깨집니다.
- **⚠️ 이 PC에서는 `.rmskin` 설치 금지.** 설치기가 기존 폴더(junction)를 `Skins\@Backup`으로 옮겨 버립니다.
- **⚠️ Clock의 설정 화면을 누르면 저장소의 `Variables.inc`가 바뀝니다.**
  - 커밋 전에 diff를 확인하세요.
  - 저장소 기본값은 `Theme=Brown`, `BgAlpha=217`, `Use24h=1`, `ShowSeconds=1`, `WeekStart=Mon`, `TempUnit=C`, `SystemDrives=C:`입니다.
  - `build-rmskin.ps1`은 `Variables.inc`를 git HEAD에서 가져옵니다. 새 변수를 추가했으면 (개인 값은 빼고) 커밋해야 패키지에 들어갑니다.
  - 사용자가 실제로 쓰는 값은 작업 폴더에만 남겨 둡니다.

## Rainmeter 함정 (직접 겪고 확인한 것)

- **DPI**: Rainmeter 4.5.28은 **DPI-unaware** 프로세스입니다(`GetProcessDpiAwareness` = 0, 2026-11-17 확인).
  - 그래서 Windows가 125%로 비트맵을 늘려 그리고, 이것이 흐릿함의 원인입니다. 안티앨리어싱 문제가 아닙니다(텍스트·Line·Histogram은 `AntiAlias=1`, Shape는 Direct2D).
  - 선명하게 하려면 Rainmeter.exe 호환성 → "높은 DPI 조정 동작 재정의: 애플리케이션"을 켜고 `SuiteScale`을 Windows 배율(1.25)로 둡니다. 이때 `!Move`·`WindowX/Y`는 물리 픽셀이 됩니다.
  - 재정의 없이 `SuiteScale`을 1.25로 하면 두 번 커집니다. 저장소 기본값은 1입니다.
- **스킨별 배율**: `Scale=(#SuiteScale#*#SkinScale#)`입니다. 스킨의 `[Variables]`에서 `SkinScale`을 다시 정의하면(Calendar: `SkinScale=#CalendarScale#`) 그 스킨의 모든 크기가 함께 커집니다.
  - include한 키를 스킨에서 다시 정의하면 **값은 나중 것, 전개 위치는 처음 것**을 따릅니다(2026-11-17 확인). 그래서 `CalendarScale`은 `Variables.inc`에서 `SkinScale`보다 앞에 둡니다.
  - `!Move` 좌표와 Rainmeter.ini의 `WindowX/Y`는 논리 좌표입니다.
- **변수는 정의 순서대로 전개됩니다.** 다른 변수를 참조하는 변수는 참조 대상보다 뒤에 둡니다.
  - 예: `CardH`는 `CtrlTop` 뒤에 둡니다.
  - `ColorBg=#ColorBgRGB#,#BgAlpha#`는 `@IncludeTheme` 뒤에 둡니다.
- **`.ini`, `.inc` 줄 끝에 `;` 주석을 달면 값의 일부가 됩니다.** 주석은 줄 맨 앞에서만 씁니다.
- **ini에 비ASCII 문자를 쓰지 않습니다.** 필요하면 `[\x2193]` 같은 문자 참조를 씁니다(이때 DynamicVariables가 필요).
- **`Substitute`에 빈 문자열과 매치될 수 있는 패턴을 쓰면 Rainmeter가 무한 루프로 멈춥니다.**
  - 예: `"^0?$":""` (실제로 겪어서 강제 종료한 적 있음)
- **Hidden 미터도 업데이트됩니다.** Image 미터는 숨겨져 있어도 이미지를 로드하려고 합니다.
- **Hidden 미터도 `DynamicWindowSize` 창 크기에 Y 위치만큼 영향을 줍니다**(높이는 0으로 계산, 2026-11-17 확인).
  - 그래서 미터를 숨겨서 카드를 줄이려면 그 미터들을 컨테이너에 넣고 컨테이너를 숨깁니다(Clock 설정 화면의 `MeterSetView`). 또는 숨긴 미터의 Y를 0으로 옮깁니다(System 드라이브 줄).
- **WebNowPlaying `Cover`**: 커버가 없으면 문자열 대신 `"0"`을 돌려줍니다. 그래서 `MeasureCoverPath`로 `^0$`를 빈 값으로 바꿔 씁니다.
- **`!WriteKeyValue`는 없는 파일을 만들지 못합니다.**
- **`!DeactivateConfig`·`!Refresh`·`!Move`·`!CommandMeasure`를 로드되지 않은 스킨에 쓰면 로그에 오류나 경고가 남습니다.**
  - 그래서 스킨끼리 서로를 켜고 끄는 설계는 피했습니다.
- **Hidden 미터의 `[Meter:H]`는 0입니다.** 그래서 `[숨길 수 있는 미터:YH]`에 기대는 CardH는 그 미터가 보일 때 커집니다.
  - 옛 Music 카드가 곡이 잡히면 커지던 원인(2026-11-17): 대기 상태에서 숨긴 시간 줄(`MeterTimes`)이 보이면서 +17px, 일본어·한글 제목이 대체 폰트로 그려지며 줄 높이 +4px.
  - 그래서 Music은 모든 위치를 변수로 계산하고(R/YH 상대 위치 없음), 화면별 컨테이너에 넣었습니다. 높이가 내용에 따라 변하면 안 되는 카드는 이렇게 합니다.
- **`!ZPos`는 Rainmeter.ini(`AlwaysOnTop`)에 저장됩니다**(2026-11-17 확인). 잠깐 올렸다 내리려면 원래 값을 따로 기억해야 합니다(ZOrder.lua는 `Cache\<이름>.zpos`).
  - 모든 스킨이 `0`(보통)이면 `!ZPos 0`을 다시 줘도 앞으로 오지 않습니다(`HWND_NOTOPMOST`는 이미 보통 창이면 효과 없음). 그래서 펼친 카드는 `1`(Topmost)로 올립니다.
  - bang은 비동기라서, `!ZPos` 직후 Rainmeter.ini를 바로 읽으면 이전 값이 나올 수 있습니다(screenshot-skins.ps1을 연달아 돌리다 Calendar·Tasks가 `2`로 남은 적 있음 → 스크립트 끝에 2초 대기).
- **Music을 `!Refresh`하다 WebNowPlaying.DLL에서 Rainmeter가 죽은 적이 있습니다**(2026-11-17, 0xc0000409, 같은 세션에서 여러 번 새로고침한 뒤). 접기/펼치기는 새로고침 없이 Lua로만 합니다.
- **AudioLevel 자식 measure는 부모 measure보다 뒤에 와야 합니다.** `@Include` 위치에 주의합니다.
- **Lua 인코딩**: 기본은 ANSI(CP949)라서 이모지나 일부 문자가 깨집니다.
  - 스크립트 파일이 **UTF-16 LE(BOM)**이면 유니코드(UTF-8) 모드로 실행됩니다.
  - 4.5.28은 UTF-8 BOM을 인식하지 못합니다(`unexpected symbol` 오류).
  - 그래서 `Calendar.lua`와 `Tasks.lua`만 UTF-16입니다.
  - Rainmeter의 Lua는 5.1이라 `\u{2026}` 같은 이스케이프가 없습니다. UTF-16 스크립트에 문자를 그대로 씁니다. git에는 `.gitattributes`의 working-tree-encoding으로 UTF-8로 저장됩니다.
  - `dofile`로 불러오는 파일(ICalParser)은 ASCII로 유지합니다.
- **Lua에서 미터/measure를 다룰 때**: `Initialize()`에서는 아직 없는 섹션이 있을 수 있습니다. 첫 `Update()`에서 그리기와 활성화를 합니다.
- **`SKIN:Bang` 인수는 `tostring`으로 넘깁니다.** 크기 변수는 `SKIN:ParseFormula(SKIN:ReplaceVariables('#Var#'))`로 숫자로 바꿉니다.
- **MeterStyle에 넣은 옵션**(Path 정의, `Extend` 대상, 그라디언트)도 Shape 미터에서 정상적으로 읽힙니다.
- **Shape `Extend`는 중첩되지 않습니다**: Extend 대상 안에 또 `Extend`가 있으면 `Extend cannot be used recursively` 경고(2026-11-17). 선 속성은 Shape 줄에 직접 쓰고 색만 `Extend IconColor`처럼 뺍니다.
- **`Combine`으로 합친 원본 도형은 그려지지 않습니다.** 날씨 아이콘은 구름을 Union으로, 해·달은 구름 모양을 Exclude로 잘라 겹침을 처리합니다(불투명 채우기 없이).
- **Calc `?:`의 안 쓰는 쪽도 0 나누기 경고를 냅니다**(`Calc: Division by 0`, 없는 드라이브, 2026-11-17). 분모를 `Max(x,1)`로 감쌉니다.
- **`StringAlign=Right` String 미터의 `[Meter:X]`는 글자 상자의 왼쪽 끝**입니다(날씨 아이콘을 기온 왼쪽에 붙일 때 확인).
- **WebParser**
  - `UpdateRate`는 업데이트 횟수입니다. `Update=1000` × `900` = 15분입니다.
  - 연결 실패 시 로그에는 원인만 남고 URL은 남지 않습니다.
  - 구글 비공개 주소의 `%40`은 그대로 전달돼 정상 동작합니다.
- **Container**: 컨테이너 미터 자체는 그려지지 않고 마스크로만 쓰입니다. 첫 내용 미터는 컨테이너 왼쪽 위 기준이고, 내용 미터는 창 크기(DynamicWindowSize)를 늘리지 않습니다(2026-11-17 확인).
- **Image 미터에 `DynamicVariables=1`을 주면 매 업데이트마다 디스크에서 이미지를 다시 읽습니다.** 그래서 `CardArt.inc`의 텍스처는 `H=(2*#CardW#)` 고정값을 쓰고 컨테이너가 자릅니다.
- **`ImageName=`이 비어 있으면** 아무것도 그리지 않고 로그도 남지 않습니다(그림 없는 테마).
- **번들 폰트**: `@Resources\Fonts`의 .ttf/.otf는 자동 로드됩니다. 웨이트가 하나뿐인 폰트에 `FontWeight=600/700`을 주면 가짜 볼드가 됩니다 → 테마에서 `FontWeightNum`/`FontWeightTitle`을 400으로.
  - Google Fonts에서 정적 TTF는 `css2?family=...` API를 구형 User-Agent(`Mozilla/4.0`)로 요청하면 받을 수 있습니다(저장소의 기본 파일은 가변 폰트).
- **`!WriteKeyValue`는 스킨 폴더 밖 경로를 거부합니다**(`Illegal path`). 저장소 경로 대신 `문서\Rainmeter\Skins\MyWindowWidget\...`(junction) 경로를 씁니다.
- **@Include한 파일에서 첫 섹션 앞에 둔 키는 include한 쪽 섹션에 합쳐지지 않습니다**(2026-11-17 확인). include 파일에서 변수를 정의하려면 그 파일에도 `[Variables]` 헤더를 씁니다.
- **RunCommand**: Lua에서 `!SetOption MeasureRun Parameter ...` → `!UpdateMeasure` → `!CommandMeasure ... Run` 순서로 하면 새 Parameter로 실행됩니다(2026-11-17 확인).
  - 기본 Program은 `%ComSpec% /U /C`(cmd.exe)입니다. 문서상 `State=Hide`는 새로고침·언로드 때 "실행한 프로그램"을 종료하는데, 그건 cmd.exe라 그 밑의 PowerShell은 남을 수 있습니다. 그래서 상주하는 GpuLoad.ps1은 mutex(한 개만) + 하트비트 파일(`gpu.alive`이 60초 넘게 안 바뀌면 종료)로 스스로 정리합니다. TODO(verify): PowerShell이 실제로 남는지.
- **UsageMonitor 플러그인(1.0.1.0)은 이 PC에서 Rainmeter를 죽입니다**(Windows 11 build 26300, `Alias=CPU`·`Alias=GPU`·Category/Counter 지정 모두, .NET NullReferenceException, 2026-11-17). 쓰지 않습니다.
  - GPU 사용률은 GpuLoad.ps1이 `PerformanceCounterCategory("GPU Engine").ReadCategory()`로 읽습니다(샘플당 CPU 약 8 ms). `Get-Counter`는 샘플당 약 1.4초라 못 씁니다.
  - 값은 작업 관리자와 같은 정의: 엔진 종류별로 프로세스 합 → 가장 큰 값.
  - 실행 중에 다시 Run하면 오류 101이 납니다. 그래서 Tasks.lua는 큐를 두고 한 번에 하나만 실행합니다.
- **InputText 입력을 Lua로 넘기기**: `[!CommandMeasure M """Add([==[$UserInput$]==])"""]`
  - 한글, `"`, `\`가 그대로 도착합니다(bang으로 같은 문자열을 넣어 2026-11-17 확인).
  - InputText는 Windows에 설치된 폰트만 쓸 수 있습니다(`InputFontFace`).
- **`@Vault`는 플러그인 설치 경로가 아닙니다.** 설치기가 사본을 보관하는 폴더이고, 실제 설치는 패키지의 `Plugins/32bit|64bit`에서 이뤄집니다.

## 내린 결정

- **오디오 비주얼라이저(원 명세 마일스톤 6)는 사용자가 취소**했습니다. 다시 요청하지 않는 한 추가하지 않습니다.
- **WebNowPlaying은 v3**를 씁니다. v2.0.7은 Windows 11 업데이트 이후 동작하지 않는다는 제작자 안내가 있습니다.
  - 옵션 이름은 v2와 v3 공통인 legacy 이름을 씁니다.
  - 데스크톱 Spotify를 별도 설정 없이 인식합니다.
- **컨셉 테마 폰트**: 한글 일정 제목이 많아 본문 폰트는 한글 지원 폰트로 골랐습니다(Christmas: Jua, Cafe: Gaegu). Christmas 숫자 폰트는 처음 Mountains of Christmas였으나 0이 작게 떠서("150"이 "15°"처럼 보임) Emilys Candy로 바꿨습니다.
  - Gaegu는 작게 그려지지만 폭이 넓어 `FontScale=1.15`가 고정 폭 카드에 들어가는 한계입니다.
- **곡 제목**은 marquee 대신 말줄임(…)으로 처리합니다(CPU 목표).
- **진행 바**는 클릭으로만 탐색합니다. Rainmeter에 마우스 이동 이벤트가 없습니다.
- **네트워크 "Today"**는 `Cumulative=1` 대신 Lua로 직접 합산합니다. 어댑터가 바뀌어도 값이 튀지 않습니다.
- **패키지**: `LoadType=Skin`(Clock만 자동 로드)입니다. `VariableFiles=Secrets.inc | Variables.inc`라 재설치해도 사용자 값이 유지됩니다.
- **Google Tasks는 API 키가 아니라 OAuth 2.0을 씁니다.** Tasks API가 OAuth 스코프만 받기 때문에, 사용자가 OAuth 데스크톱 방식으로 결정했습니다(2026-11-17).
  - `GTasks.ps1 -Action setup`: loopback(127.0.0.1, TcpListener라 관리자 권한 불필요) + PKCE.
  - 클라이언트 ID·비밀·refresh token은 DPAPI(CurrentUser)로 암호화해 `%LOCALAPPDATA%\MyWindowWidget\GoogleTasks`에 둡니다(저장소·패키지 밖).
  - 동의 화면이 Testing 상태면 refresh token이 7일 뒤 만료됩니다. README에서 In production 전환을 안내합니다.
  - HTTP는 내장 RunCommand 플러그인 + Windows PowerShell 5.1로 합니다(WebParser는 POST/PATCH 불가). 추가 입력은 내장 InputText입니다.
  - fetch 한 번에 모든 목록을 받습니다. 결과는 `Cache\tasks.txt`(형식은 GTasks.ps1 머리말), 보던 쪽은 `tasks.page`, 추가할 제목은 `tasks.new`입니다. 명령줄에는 검증한 id만 넣고, 제목은 파일로 넘깁니다.
  - 정렬은 GTasks.ps1에서 합니다: 마감일 빠른 순, 마감일 없음은 뒤, 같으면 구글 position. 하위 할 일은 상위 아래에서 같은 규칙.
  - 카드는 config 하나(`Tasks`)입니다(2026-11-17 개편, 그전에는 목록마다 config `List1..4`).
    - 높이는 `CalendarHeight`입니다. Calendar의 CardH를 식으로 풀어 Variables.inc에 두고 두 스킨이 같이 씁니다. Calendar 레이아웃을 바꾸면 이 식도 바꿉니다.
    - 폭은 System/Network와 같은 300, 글자 배율은 1(Calendar처럼 1.5배가 아님)입니다.
    - 목록 1~3개는 같은 높이의 구역으로 나누고, 4개 이상이면 3구역 + `< >` 페이지입니다(마지막 쪽은 마지막 3개). 줄 미터 22개와 구역 미터 3벌을 Lua가 배치합니다.
    - 추가 입력창은 Lua가 `!SetOption MeasureTaskInput Y`로 구역 머리줄 위로 옮긴 뒤 엽니다.
  - 추가·완료만 지원합니다(수정·삭제·완료 취소 없음).
- **Clock + Settings 통합 (2026-11-17, 사용자 요청)**: Settings config는 없앴고, Clock 카드 오른쪽 위 "설정" 버튼(한국어 라벨은 사용자 요청, `[\xC124][\xC815]`)이 같은 카드를 설정 화면으로 바꿉니다. ✕로 돌아옵니다. 시계의 날짜 줄은 사용자 요청으로 없앴습니다.
  - 화면 전환은 Settings.lua: `CardH`를 `CardHClock`/`CardHSet`으로, 그룹 `ClockView` / `SetView`(+컨테이너 `MeterSetView`)를 보이고 숨김. AM/PM·초 표시도 Lua가 정합니다.
  - 설정을 바꾸면 전체 새로고침 전에 `Cache\clock.view`에 `settings`를 써 두고, 다시 로드될 때 설정 화면으로 열고 지웁니다(Rainmeter 재시작은 시계 화면).
  - 이전의 접기 기능(`SettingsCollapsed`)은 없앴습니다.
- **날씨 (Clock)**: 위치는 Windows 위치 서비스(System.Device.Location, 이 PC에서 Wi-Fi 기반 약 200 m), 날씨는 Open-Meteo(키 없음, CC BY 4.0 → 툴팁에 출처), 지명은 BigDataCloud `reverse-geocode-client`(무료, 기기 위치를 기기에서 부르는 조건).
  - Nominatim은 정책상 주기적 요청을 금지하고 원격 차단 스위치를 요구해서 쓰지 않았습니다.
  - 좌표는 소수 둘째 자리로 반올림해서 보내고 캐시합니다. 지명은 좌표·언어가 바뀔 때만 다시 묻습니다.
  - 항상 섭씨·km/h로 받고 °F 변환은 Lua(`TempUnit`)가 합니다. 그래서 단위를 바꿔도 다시 받지 않습니다.
  - 2026-11-17에 `api.open-meteo.com` 자체가 약 15분 동안 응답하지 않은 적이 있습니다(다른 Open-Meteo 호스트는 정상). 실패하면 마지막 값을 유지하고 5분 뒤 재시도합니다.
- **System**: CPU·GPU 그래프 2줄, RAM, 드라이브 줄(`SystemDrives`, 최대 4, 없는 드라이브는 숨기고 30초마다 다시 확인). 카드 높이는 내용에 맞춰 바뀝니다(이전처럼 Calendar 높이에 맞춘 고정값이 아님).
  - 이 PC의 G:는 Google Drive 가상 드라이브라 기본값에 넣지 않았습니다.
- **Tasks 동기화 표시**: 헤더 오른쪽에 동기화 버튼(⟳)과 `Updated 5m ago`(1초마다 갱신, 글자가 바뀔 때만 다시 그림). 시각은 tasks.txt의 `updated` 줄(초까지)입니다.
- **Music 접기/펼치기 (2026-11-17, 사용자 요청)**: config 하나, 오른쪽 위 chevron으로 전환(Music.lua, 상태는 `Cache\music.view`).
  - 접힘: 높이 = Clock 카드(`ClockHeight`, Clock.ini의 CardHClock을 식으로 풀어 Variables.inc에 둠. Clock 레이아웃을 바꾸면 같이 바꿉니다). 커버가 높이를 채우고, 제목·아티스트, 이전/재생/다음, 진행 바.
  - 펼침: 큰 커버(`ArtSizeL`), 제목/아티스트/앨범/시간, 전체 폭 진행 바, 셔플/이전/재생/다음/반복.
  - 폭은 둘 다 `MusicWidth`(340)입니다. Clock(380)+Music(340) = Tasks(300)+Calendar(420)이라 이 PC 배치에서 Clock 옆에 두면 오른쪽 끝이 Calendar와 맞습니다.
  - 상태에 따른 표시(커버, 재생/일시정지 아이콘, 진행 바, 반복 1)는 IfAction이 아니라 Lua가 화면을 보고 정합니다. 화면 그룹을 보이면 둘 다 보이는 문제를 피하려는 것입니다.
- **펼친 카드는 Topmost**: Music 펼침과 Clock 설정 화면은 아래 카드를 덮으므로 열려 있는 동안 `!ZPos 1`, 닫으면 사용자의 원래 값으로 되돌립니다(ZOrder.lua). 원래 값이 이미 1 이상이면 건드리지 않습니다.
  - 그동안은 다른 앱 창 위에도 뜹니다. 위젯끼리만 올리는 방법은 외부 플러그인 없이는 찾지 못했습니다.
- **라이선스**: MIT (© 2026 leafbell-sii). WebNowPlaying(MIT) 고지는 패키지에 함께 넣습니다.

## 남은 일 / 아이디어

- `.rmskin` **실제 설치 테스트**: 다른 PC, 또는 junction을 해제한 상태에서 해야 합니다.
- **이번 개편(2026-11-17) 미검증 항목**
  - 날씨: 위치 서비스가 꺼진 경우(`Location off`) 화면 — 이 PC 설정을 바꿀 수 없어 확인 못 함. 여러 줄 툴팁(Lua에서 `\r\n`)이 실제로 줄바꿈되는지.
  - 마우스로 직접 누르는 것(설정 버튼 hover, ✕, 동기화 버튼, 날씨 클릭)은 bang으로만 확인했습니다.
  - 테마별(특히 Christmas, 기본 테마) Clock/System 모양은 Cafe에서만 봤습니다.
- **Tasks 미검증 항목**: 입력창(InputText)이 열린 모양과 위치(DPI 재정의 환경, `!SetOption Y`로 구역마다 옮기는 것 포함)는 아직 확인하지 못했습니다.
  - 단일 카드 개편 후(2026-11-17) 확인한 것: 실제 계정 fetch와 정렬, 2구역 표시, 가짜 캐시로 5개 목록 페이지 전환·`+N more`·하위 할 일. 추가·완료는 개편 후 다시 해 보지 않았습니다.
  - 실제 계정으로 확인한 것(2026-11-17): setup, 조회(목록 2개), bang 경로로 한글·따옴표 제목 추가 → 완료, 목록 전환. 로그 오류 없음.
  - 키 입력을 흉내 내는 테스트(SendKeys)는 쓰지 않습니다. 포커스가 다른 창에 있으면 사용자 창에 입력됩니다.
- **Music 미검증 항목**: 재생 중일 때 일시정지 아이콘 전환과 진행 바 클릭 탐색은 아직 확인하지 못했습니다(일시정지 상태 표시는 확인함).
  - 접기/펼치기(2026-11-17)는 bang(`Toggle()`)으로만 눌러 봤습니다. Cafe 테마에서만 화면을 봤고, 실제 "Nothing playing" 상태는 Spotify를 끄지 않고 텍스트·미터를 bang으로 바꿔 크기만 확인했습니다.
- **Calendar 미지원 반복 규칙**: `MONTHLY`/`YEARLY` + `BYDAY`("둘째 화요일"), `BYMONTHDAY`, `RDATE`는 첫 회차만 표시합니다.
- **Calendar 시간대**: Asia/Seoul이 아닌 TZID는 로컬 시간으로 취급합니다(VTIMEZONE 미해석).
- 명세의 선택 범위 밖이었던 것: GPU 온도, Clock 보조 타임존. (Disk·Weather·GPU 사용률은 2026-11-17에 추가)
- 기본 테마(Brown/Slate/Forest/Mono)는 여전히 시스템 폰트 Segoe UI를 씁니다.
