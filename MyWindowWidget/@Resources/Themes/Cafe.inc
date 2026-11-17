; =============================================================
;  MyWindowWidget theme: Cafe (concept theme)
;  Color format: R,G,B,A  (A: 0 = transparent, 255 = opaque)
;  Card opacity is NOT set here: Variables.inc builds ColorBg /
;  ColorBgHover / ColorOnAccent from ColorBgRGB + BgAlpha, so the
;  Settings skin can change opacity for every theme.
;
;  A concept theme also sets fonts and card art; any key from the
;  "Theme defaults" block of Variables.inc can be overridden here.
;  Fonts:  Gaegu (OFL, handwritten, has Hangul) for all text.
;  Art:    @Resources\Images\Cafe (tools/dev/make-concept-art.py)
; =============================================================
[Variables]
; Light latte paper, espresso text, cinnamon accent.
; Card background colour (R,G,B only - opacity is BgAlpha).
ColorBgRGB=238,226,206
ColorBgAlt=222,204,178,220
ColorBorder=140,100,70,90
ColorTextPrimary=66,42,28,255
ColorTextSecondary=128,98,76,255
ColorTextMuted=128,98,76,100
ColorAccent=176,96,62,255
ColorAccentDim=176,96,62,90
ColorAccentSoft=176,96,62,45
ColorWarn=200,60,46,255
; Calendar dots, one per iCal feed (ICalUrl1..4).
ColorCal1=176,96,62,255
ColorCal2=106,140,84,255
ColorCal3=84,120,162,255
ColorCal4=170,80,112,255

; ---- Fonts --------------------------------------------------
FontFace=Gaegu
FontFaceNum=Gaegu
FontWeightNum=700
FontWeightTitle=700
; Gaegu draws small (capitals ~25% shorter than Segoe UI's) but
; wide; 1.15 is the most that still fits the fixed-width cards.
FontScale=1.15
; Metrics from tools/dev/font-metrics.py
FontCapTop=0.316
FontAscent=1.016
FontCapTopNum=0.316
FontAscentNum=1.016
FontDescentNum=0.323

; ---- Card art -----------------------------------------------
CardTexture=#@#Images\Cafe\Texture.png
CardTrim=#@#Images\Cafe\Trim.png
CardTrimH=14
