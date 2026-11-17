; =============================================================
;  MyWindowWidget theme: Brown (default)
;  Color format: R,G,B,A  (A: 0 = transparent, 255 = opaque)
;  Card opacity is NOT set here: Variables.inc builds ColorBg /
;  ColorBgHover / ColorOnAccent from ColorBgRGB + BgAlpha, so the
;  Settings skin can change opacity for every theme.
;  To add a theme: copy this file, rename it, add the name to
;  ThemeList in Variables.inc.
; =============================================================
[Variables]
; Warm umber-brown tones mixed with ~30% black.
; Card background colour (R,G,B only - opacity is BgAlpha).
ColorBgRGB=32,22,17
ColorBgAlt=49,35,27,190
ColorBorder=160,120,90,80
ColorTextPrimary=242,232,220,255
ColorTextSecondary=190,170,150,255
ColorTextMuted=190,170,150,90
ColorAccent=214,154,96,255
ColorAccentDim=214,154,96,90
ColorAccentSoft=214,154,96,40
ColorWarn=220,110,80,255
; Calendar dots, one per iCal feed (ICalUrl1..4).
ColorCal1=214,154,96,255
ColorCal2=150,180,125,255
ColorCal3=125,160,200,255
ColorCal4=205,125,140,255
