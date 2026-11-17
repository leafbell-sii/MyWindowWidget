; =============================================================
;  MyWindowWidget - shared design variables
;  Included by every skin. Change values here, then refresh
;  all MyWindowWidget skins (right-click a skin > Refresh, or run
;  !RefreshGroup MyWindowWidget).
; =============================================================
[Variables]

; ---- Theme --------------------------------------------------
; The Settings skin writes Theme / BgAlpha / BgAlphaHover here.
; Name of a file in @Resources\Themes\ (without .inc).
Theme=Mono
; Themes offered by the Settings skin (max 4), separated by |.
ThemeList=Brown|Slate|Forest|Mono
; Card opacity 0-255 (178 = 70%, 217 = 85%, 255 = 100%).
BgAlpha=255
; Opacity while the mouse is over a card.
BgAlphaHover=255
@IncludeTheme=#@#Themes\#Theme#.inc
; Built from the theme's ColorBgRGB (must come after the include).
ColorBg=#ColorBgRGB#,#BgAlpha#
ColorBgHover=#ColorBgRGB#,#BgAlphaHover#
ColorOnAccent=#ColorBgRGB#,255

; ---- Scale --------------------------------------------------
; Overall size multiplier for every size below.
; Keep 1: Windows stretches Rainmeter to the display scaling
; (125% / 150%), which looks soft. For sharp skins, set
; Rainmeter.exe > Properties > Compatibility > high DPI
; override = Application, then set this to the display
; scaling (1.25 / 1.5). See README.
; Other values just make the suite larger or smaller.
SuiteScale=1.25
; Calendar card size relative to the rest of the suite.
CalendarScale=1.5
; Per-skin multiplier. Leave 1 here: a skin that is drawn
; larger overrides it in its own [Variables] (the Calendar sets
; SkinScale=#CalendarScale#). Must come before Scale.
SkinScale=1
; Effective multiplier used by every size below and by the
; skins' own (N*#Scale#) sizes.
Scale=(#SuiteScale#*#SkinScale#)

; ---- Typography ---------------------------------------------
; TODO: switch to a bundled font (Inter / Manrope) placed in
;       @Resources\Fonts once one is chosen.
FontFace=Segoe UI
FontFaceNum=Segoe UI
FontWeightNum=600
FontSizeXL=(42*#Scale#)
FontSizeL=(16*#Scale#)
FontSizeM=(11*#Scale#)
FontSizeS=(9*#Scale#)

; ---- Layout -------------------------------------------------
Radius=(12*#Scale#)
Pad=(14*#Scale#)
Gap=(8*#Scale#)
WidgetWidth=(260*#Scale#)
; Short cards (System, Network): four of them plus three Gaps
; are about as tall as the Calendar (CalendarScale 1.5).
CompactWidth=(300*#Scale#)
CompactHeight=(138*#Scale#)
; Thin bars (RAM bar, separators)
BarH=(4*#Scale#)
; Shape-drawn icons
ArrowS=(11*#Scale#)
ArrowStrokeW=(1.6*#Scale#)
; Music card
MusicWidth=(340*#Scale#)
ArtSize=(64*#Scale#)
ArtRadius=(8*#Scale#)
IconSize=(14*#Scale#)
IconStrokeW=(1.5*#Scale#)
PlayButtonSize=(30*#Scale#)
; Calendar card
CalendarWidth=(280*#Scale#)

; ---- Behaviour ----------------------------------------------
; Values at or above this percent turn ColorWarn (System skin).
WarnThreshold=80
; Clock: 1 = 24-hour, 0 = 12-hour with AM/PM
Use24h=0
; Clock: 1 = show seconds next to the time
ShowSeconds=1
; Network: 0 = bytes (KB/s, MB/s), 1 = bits (Kb/s, Mb/s)
UseBits=0
; Calendar: first day of the week, Mon or Sun
WeekStart=Mon
; Calendar: events with this TZID (and floating times) are taken
; as local time. Feed URLs go in Secrets.inc, not here.
LocalTZID=Asia/Seoul
; Calendar: how often to re-download the iCal feeds, in seconds
; (Google's feed itself can lag minutes to hours).
ICalRefreshSeconds=900

; ---- Internal (used by the shared styles) -------------------
BgFill=#ColorBg#
HoverIn=[!SetVariable BgFill "#ColorBgHover#"][!UpdateMeter MeterBg][!Redraw]
HoverOut=[!SetVariable BgFill "#ColorBg#"][!UpdateMeter MeterBg][!Redraw]
