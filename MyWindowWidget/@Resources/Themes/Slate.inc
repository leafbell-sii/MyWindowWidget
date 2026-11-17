; =============================================================
;  MyWindowWidget theme: Slate
;  Color format: R,G,B,A  (A: 0 = transparent, 255 = opaque)
;  Card opacity is NOT set here: Variables.inc builds ColorBg /
;  ColorBgHover / ColorOnAccent from ColorBgRGB + BgAlpha, so the
;  settings view (Clock card) can change opacity for every theme.
;  To add a theme: copy this file, rename it, add the name to
;  ThemeList in Variables.inc.
; =============================================================
[Variables]
; Cool blue-grey with a steel-blue accent.
; Card background colour (R,G,B only - opacity is BgAlpha).
ColorBgRGB=24,28,34
ColorBgAlt=40,46,56,190
ColorBorder=120,135,155,80
ColorTextPrimary=230,235,242,255
ColorTextSecondary=160,170,185,255
ColorTextMuted=160,170,185,90
ColorAccent=120,170,220,255
ColorAccentDim=120,170,220,90
ColorAccentSoft=120,170,220,40
ColorWarn=230,110,90,255
; Calendar dots, one per iCal feed (ICalUrl1..4).
ColorCal1=120,170,220,255
ColorCal2=150,190,140,255
ColorCal3=210,160,100,255
ColorCal4=200,130,170,255
