# CLAUDE.md — MyWindowWidget 작업 인수인계

Rainmeter 위젯 모음 **MyWindowWidget**의 저장소입니다. 원래 명세(Umber 스위트)의 마일스톤은 모두 끝났고, 이 문서가 그 명세를 대신합니다.
사용자용 설명은 [MyWindowWidget/README.md](MyWindowWidget/README.md)에 있습니다.

## 작업 원칙

- **답변은 한국어로.** 코드, 주석, 위젯 UI 문구는 영어로 씁니다.
- **디자인 값 하드코딩 금지.**
  - 색은 `@Resources/Themes/*.inc`, 크기·간격·폰트·동작 설정은 `@Resources/Variables.inc`에서만 가져옵니다.
  - 크기는 `(N*#Scale#)` 형태로 씁니다.
- **외부 플러그인은 WebNowPlaying 하나만** 씁니다. 나머지는 내장 measure/plugin으로 구현합니다.
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
    Variables.inc            공용 설정. Theme/BgAlpha/Use24h 등. Settings 스킨이 여기에 씀
    Styles.inc               공용 MeterStyle (StyleCard, StyleTitle, StyleValue ...)
    Themes/*.inc             색 테마 (ColorBgRGB + 나머지 R,G,B,A). ThemeList에 등록
    Secrets.inc              실제 iCal 주소 (git 제외) / Secrets.example.inc 템플릿
    Cache/                   런타임 캐시 (calN.ics, NetToday.txt) - git 제외
    Scripts/                 Lua: Calendar, ICalParser, Music, Network, Settings
  Clock/ System/ Network/ Music/ Calendar/ Settings/   스킨 (.ini 하나씩)
vendor/WebNowPlaying/        플러그인 DLL 32/64bit (v3.0.0-alpha.5, sha256은 SOURCE.md)
tools/build-rmskin.ps1       dist/MyWindowWidget_<버전>.rmskin 생성
tools/dev/                   read-rainmeter-log.ps1, screenshot-skins.ps1
```

- 모든 스킨은 `Group=MyWindowWidget`입니다. Settings는 값을 바꾼 뒤 `!RefreshGroup MyWindowWidget`으로 전체를 새로고침합니다.
- 카드 배경은 각 스킨의 `[Variables]`에 `CardW` / `CardH`를 정하고 `MeterStyle=StyleCard`를 씁니다.
  - `CardH`는 보통 `([마지막미터:YH]+#Pad#)` 형태입니다.

## 개발 루프 (이 PC 기준)

- **연결**: `문서\Rainmeter\Skins\MyWindowWidget`이 저장소의 `MyWindowWidget/`를 가리키는 **junction**입니다.
  - 파일을 고친 뒤 `Rainmeter.exe !Refresh "MyWindowWidget\Clock"`이나 `!RefreshGroup MyWindowWidget`을 실행하면 바로 반영됩니다.
  - 새 config 폴더를 추가했으면 먼저 `!RefreshApp`을 실행합니다.
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
- **⚠️ Settings 스킨을 누르면 저장소의 `Variables.inc`가 바뀝니다.**
  - 커밋 전에 diff를 확인하세요.
  - 저장소 기본값은 `Theme=Brown`, `BgAlpha=217`, `Use24h=1`, `ShowSeconds=1`, `WeekStart=Mon`입니다.
  - 사용자가 실제로 쓰는 값은 작업 폴더에만 남겨 둡니다.

## Rainmeter 함정 (직접 겪고 확인한 것)

- **DPI**: Rainmeter 4.5는 Windows 배율을 이미 적용합니다. `Scale`은 1로 둡니다(1.25로 하면 두 배로 커짐).
  - `!Move` 좌표와 Rainmeter.ini의 `WindowX/Y`는 논리 좌표입니다.
- **변수는 정의 순서대로 전개됩니다.** 다른 변수를 참조하는 변수는 참조 대상보다 뒤에 둡니다.
  - 예: `CardH`는 `CtrlTop` 뒤에 둡니다.
  - `ColorBg=#ColorBgRGB#,#BgAlpha#`는 `@IncludeTheme` 뒤에 둡니다.
- **`.ini`, `.inc` 줄 끝에 `;` 주석을 달면 값의 일부가 됩니다.** 주석은 줄 맨 앞에서만 씁니다.
- **ini에 비ASCII 문자를 쓰지 않습니다.** 필요하면 `[\x2193]` 같은 문자 참조를 씁니다(이때 DynamicVariables가 필요).
- **`Substitute`에 빈 문자열과 매치될 수 있는 패턴을 쓰면 Rainmeter가 무한 루프로 멈춥니다.**
  - 예: `"^0?$":""` (실제로 겪어서 강제 종료한 적 있음)
- **Hidden 미터도 업데이트됩니다.** Image 미터는 숨겨져 있어도 이미지를 로드하려고 합니다.
- **WebNowPlaying `Cover`**: 커버가 없으면 문자열 대신 `"0"`을 돌려줍니다. 그래서 `MeasureCoverPath`로 `^0$`를 빈 값으로 바꿔 씁니다.
- **`!WriteKeyValue`는 없는 파일을 만들지 못합니다.**
- **`!DeactivateConfig`·`!Refresh`·`!Move`·`!CommandMeasure`를 로드되지 않은 스킨에 쓰면 로그에 오류나 경고가 남습니다.**
  - 그래서 스킨끼리 서로를 켜고 끄는 설계는 피했습니다.
- **AudioLevel 자식 measure는 부모 measure보다 뒤에 와야 합니다.** `@Include` 위치에 주의합니다.
- **Lua 인코딩**: 기본은 ANSI(CP949)라서 이모지나 일부 문자가 깨집니다.
  - 스크립트 파일이 **UTF-16 LE(BOM)**이면 유니코드(UTF-8) 모드로 실행됩니다.
  - 4.5.28은 UTF-8 BOM을 인식하지 못합니다(`unexpected symbol` 오류).
  - 그래서 `Calendar.lua`만 UTF-16입니다. git에는 `.gitattributes`의 working-tree-encoding으로 UTF-8로 저장됩니다.
  - `dofile`로 불러오는 파일(ICalParser)은 ASCII로 유지합니다.
- **Lua에서 미터/measure를 다룰 때**: `Initialize()`에서는 아직 없는 섹션이 있을 수 있습니다. 첫 `Update()`에서 그리기와 활성화를 합니다.
- **`SKIN:Bang` 인수는 `tostring`으로 넘깁니다.** 크기 변수는 `SKIN:ParseFormula(SKIN:ReplaceVariables('#Var#'))`로 숫자로 바꿉니다.
- **MeterStyle에 넣은 옵션**(Path 정의, `Extend` 대상, 그라디언트)도 Shape 미터에서 정상적으로 읽힙니다.
- **WebParser**
  - `UpdateRate`는 업데이트 횟수입니다. `Update=1000` × `900` = 15분입니다.
  - 연결 실패 시 로그에는 원인만 남고 URL은 남지 않습니다.
  - 구글 비공개 주소의 `%40`은 그대로 전달돼 정상 동작합니다.
- **`@Vault`는 플러그인 설치 경로가 아닙니다.** 설치기가 사본을 보관하는 폴더이고, 실제 설치는 패키지의 `Plugins/32bit|64bit`에서 이뤄집니다.

## 내린 결정

- **오디오 비주얼라이저(원 명세 마일스톤 6)는 사용자가 취소**했습니다. 다시 요청하지 않는 한 추가하지 않습니다.
- **WebNowPlaying은 v3**를 씁니다. v2.0.7은 Windows 11 업데이트 이후 동작하지 않는다는 제작자 안내가 있습니다.
  - 옵션 이름은 v2와 v3 공통인 legacy 이름을 씁니다.
  - 데스크톱 Spotify를 별도 설정 없이 인식합니다.
- **곡 제목**은 marquee 대신 말줄임(…)으로 처리합니다(CPU 목표).
- **진행 바**는 클릭으로만 탐색합니다. Rainmeter에 마우스 이동 이벤트가 없습니다.
- **네트워크 "Today"**는 `Cumulative=1` 대신 Lua로 직접 합산합니다. 어댑터가 바뀌어도 값이 튀지 않습니다.
- **패키지**: `LoadType=Skin`(Clock만 자동 로드)입니다. `VariableFiles=Secrets.inc | Variables.inc`라 재설치해도 사용자 값이 유지됩니다.
- **라이선스**: MIT (© 2026 leafbell-sii). WebNowPlaying(MIT) 고지는 패키지에 함께 넣습니다.

## 남은 일 / 아이디어

- `.rmskin` **실제 설치 테스트**: 다른 PC, 또는 junction을 해제한 상태에서 해야 합니다.
- **Music 미검증 항목**: 재생 중일 때 일시정지 아이콘 전환과 진행 바 클릭 탐색은 아직 확인하지 못했습니다(일시정지 상태 표시는 확인함).
- **Calendar 미지원 반복 규칙**: `MONTHLY`/`YEARLY` + `BYDAY`("둘째 화요일"), `BYMONTHDAY`, `RDATE`는 첫 회차만 표시합니다.
- **Calendar 시간대**: Asia/Seoul이 아닌 TZID는 로컬 시간으로 취급합니다(VTIMEZONE 미해석).
- 명세의 선택 범위 밖이었던 것: Disk, Weather, GPU/온도, Clock 보조 타임존.
- 번들 폰트 미정: `Variables.inc`의 `FontFace`에 TODO가 있습니다.
