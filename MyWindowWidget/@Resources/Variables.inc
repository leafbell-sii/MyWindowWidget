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
Theme=Cafe
; Themes offered by the Settings skin (max 8), separated by |.
ThemeList=Brown|Slate|Forest|Mono|Christmas|Cafe
; Card opacity 0-255 (178 = 70%, 217 = 85%, 255 = 100%).
BgAlpha=255
; Opacity while the mouse is over a card.
BgAlphaHover=255

; ---- Theme defaults -----------------------------------------
; A theme file may override everything in this block (fonts and
; card art). The defaults must come BEFORE @IncludeTheme: when a
; key is defined twice, the later value wins.
;
; Fonts. Any .ttf / .otf in @Resources\Fonts is loaded
; automatically; use the family name, not the file name.
; FontFaceNum is used for large values (clock, CPU %, ...).
FontFace=Segoe UI
FontFaceNum=Segoe UI
FontWeightNum=600
; Weight of small uppercase titles and the AM/PM label.
FontWeightTitle=600
; Multiplies every FontSize below (for fonts that draw small).
; Fixed text columns (Calendar WhenW, System RamDetailW,
; Network UnitW) grow with it too.
FontScale=1
; Font metrics in px per pt, used to line up text of different
; sizes (Clock). Defaults are Segoe UI; tools/dev/font-metrics.py
; prints them for another font.
;   CapTop  - top of the text box to the top of capitals/digits
;   Ascent  - top of the text box to the baseline
;   Descent - baseline to the bottom of the text box
; FontX = FontFace, FontXNum = FontFaceNum.
FontCapTop=0.505
FontAscent=1.439
FontCapTopNum=0.505
FontAscentNum=1.439
FontDescentNum=0.335
; Card art (see @Resources\CardArt.inc). Empty = plain card.
;   CardTexture - seamless tile over the whole card
;   CardTrim    - tile repeated along the top edge, CardTrimH px tall
CardTexture=
CardTrim=
CardTrimH=0

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
; Font faces and weights are in "Theme defaults" above.
FontSizeXL=(42*#Scale#*#FontScale#)
FontSizeL=(16*#Scale#*#FontScale#)
FontSizeM=(11*#Scale#*#FontScale#)
FontSizeS=(9*#Scale#*#FontScale#)

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
