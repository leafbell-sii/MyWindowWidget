; =============================================================
;  MyWindowWidget theme: Mono
;  Color format: R,G,B,A  (A: 0 = transparent, 255 = opaque)
;  Card opacity is NOT set here: Variables.inc builds ColorBg /
;  ColorBgHover / ColorOnAccent from ColorBgRGB + BgAlpha, so the
;  Settings skin can change opacity for every theme.
;  To add a theme: copy this file, rename it, add the name to
;  ThemeList in Variables.inc.
; =============================================================
[Variables]
; Neutral charcoal, near-white accent.
; Card background colour (R,G,B only - opacity is BgAlpha).
ColorBgRGB=22,22,24
ColorBgAlt=40,40,44,190
ColorBorder=130,130,140,70
ColorTextPrimary=236,236,238,255
ColorTextSecondary=165,165,172,255
ColorTextMuted=165,165,172,90
ColorAccent=220,220,225,255
ColorAccentDim=220,220,225,80
ColorAccentSoft=220,220,225,35
ColorWarn=230,110,90,255
; Calendar dots, one per iCal feed (ICalUrl1..4).
ColorCal1=220,220,225,255
ColorCal2=150,190,140,255
ColorCal3=120,160,200,255
ColorCal4=214,154,96,255
