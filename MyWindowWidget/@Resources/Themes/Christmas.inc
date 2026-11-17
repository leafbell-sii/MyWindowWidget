; =============================================================
;  MyWindowWidget theme: Christmas (concept theme)
;  Color format: R,G,B,A  (A: 0 = transparent, 255 = opaque)
;  Card opacity is NOT set here: Variables.inc builds ColorBg /
;  ColorBgHover / ColorOnAccent from ColorBgRGB + BgAlpha, so the
;  settings view (Clock card) can change opacity for every theme.
;
;  A concept theme also sets fonts and card art; any key from the
;  "Theme defaults" block of Variables.inc can be overridden here.
;  Fonts:  Emilys Candy (OFL) for values and the clock,
;          Jua (OFL, has Hangul) for everything else.
;  Art:    @Resources\Images\Christmas (tools/dev/make-concept-art.py)
; =============================================================
[Variables]
; Deep evergreen card, snow-white text, gold accent.
; Card background colour (R,G,B only - opacity is BgAlpha).
ColorBgRGB=22,46,34
ColorBgAlt=38,68,52,190
ColorBorder=214,180,110,80
ColorTextPrimary=248,242,228,255
ColorTextSecondary=188,206,188,255
ColorTextMuted=188,206,188,90
ColorAccent=236,190,96,255
ColorAccentDim=236,190,96,90
ColorAccentSoft=236,190,96,40
ColorWarn=236,92,84,255
; Calendar dots, one per iCal feed (ICalUrl1..4).
ColorCal1=236,190,96,255
ColorCal2=232,96,88,255
ColorCal3=150,204,150,255
ColorCal4=140,180,232,255

; ---- Fonts --------------------------------------------------
FontFace=Jua
FontFaceNum=Emilys Candy
; Both fonts have a single weight; 600 / 700 would fake-bold them.
FontWeightNum=400
FontWeightTitle=400
FontScale=1
; Metrics from tools/dev/font-metrics.py
FontCapTop=0.217
FontAscent=1.165
FontCapTopNum=0.305
FontAscentNum=1.297
FontDescentNum=0.382

; ---- Card art -----------------------------------------------
CardTexture=#@#Images\Christmas\Texture.png
CardTrim=#@#Images\Christmas\Trim.png
CardTrimH=16
