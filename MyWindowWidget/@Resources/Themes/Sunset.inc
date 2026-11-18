; =============================================================
;  MyWindowWidget theme: Sunset (concept theme)
;  Color format: R,G,B,A  (A: 0 = transparent, 255 = opaque)
;  Card opacity is NOT set here: Variables.inc builds ColorBg /
;  ColorBgHover / ColorOnAccent from ColorBgRGB + BgAlpha, so the
;  settings view (Clock card) can change opacity for every theme.
;
;  A concept theme also sets fonts and card art; any key from the
;  "Theme defaults" block of Variables.inc can be overridden here.
;  Fonts:  Gowun Batang Bold (OFL, Latin subset) for values and
;          the clock, Gowun Dodum (OFL, has Hangul) for the rest.
;  Art:    @Resources\Images\Sunset (tools/dev/make-concept-art.py)
; =============================================================
[Variables]
; Golden hour, backlit: a dusky red-brown card like the
; silhouettes against the sky, warm cream text, amber accent.
; Card background colour (R,G,B only - opacity is BgAlpha).
ColorBgRGB=48,20,22
ColorBgAlt=78,34,30,190
ColorBorder=255,170,100,80
ColorTextPrimary=255,240,222,255
ColorTextSecondary=242,186,148,255
ColorTextMuted=242,186,148,95
ColorAccent=255,172,84,255
ColorAccentDim=255,172,84,90
ColorAccentSoft=255,172,84,40
ColorWarn=255,104,82,255
; Calendar dots, one per iCal feed (ICalUrl1..4).
ColorCal1=255,172,84,255
ColorCal2=240,112,108,255
ColorCal3=176,156,226,255
ColorCal4=246,222,130,255

; ---- Fonts --------------------------------------------------
FontFace=Gowun Dodum
FontFaceNum=Gowun Batang
; Gowun Dodum has one weight (600 / 700 would fake-bold it);
; only the Bold of Gowun Batang is bundled.
FontWeightNum=700
FontWeightTitle=400
FontScale=1
; Metrics from tools/dev/font-metrics.py
FontCapTop=0.513
FontAscent=1.547
FontCapTopNum=0.507
FontAscentNum=1.547
FontDescentNum=0.384

; ---- Card art -----------------------------------------------
CardTexture=#@#Images\Sunset\Texture.png
CardTrim=#@#Images\Sunset\Trim.png
CardTrimH=16
