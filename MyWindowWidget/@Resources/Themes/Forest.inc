; =============================================================
;  MyWindowWidget theme: Forest
;  Color format: R,G,B,A  (A: 0 = transparent, 255 = opaque)
;  Card opacity is NOT set here: Variables.inc builds ColorBg /
;  ColorBgHover / ColorOnAccent from ColorBgRGB + BgAlpha, so the
;  Settings skin can change opacity for every theme.
;  To add a theme: copy this file, rename it, add the name to
;  ThemeList in Variables.inc.
; =============================================================
[Variables]
; Deep green with a moss accent.
; Card background colour (R,G,B only - opacity is BgAlpha).
ColorBgRGB=20,28,22
ColorBgAlt=34,46,37,190
ColorBorder=110,140,110,80
ColorTextPrimary=232,238,226,255
ColorTextSecondary=168,182,160,255
ColorTextMuted=168,182,160,90
ColorAccent=150,190,110,255
ColorAccentDim=150,190,110,90
ColorAccentSoft=150,190,110,40
ColorWarn=225,120,85,255
; Calendar dots, one per iCal feed (ICalUrl1..4).
ColorCal1=150,190,110,255
ColorCal2=214,170,100,255
ColorCal3=120,160,200,255
ColorCal4=205,130,140,255
