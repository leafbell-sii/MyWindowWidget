; =============================================================
;  Umber - shared meter styles
;  Combine with MeterStyle=StyleA | StyleB (later wins).
;  Requires Variables.inc to be included first.
;
;  Each skin defines in its own [Variables]:
;    CardW  - card width
;    CardH  - card height (usually ([LastMeter:YH]+#Pad#))
; =============================================================

; ---- Card background ----------------------------------------
; Rounded translucent card with a 1px border. The 0.5 offsets
; keep the 1px stroke on whole pixels so it stays crisp.
[StyleCard]
Shape=Rectangle 0.5,0.5,(#CardW#-1),(#CardH#-1),#Radius# | Fill Color #BgFill# | StrokeWidth 1 | Stroke Color #ColorBorder#
DynamicVariables=1

; ---- Text base ----------------------------------------------
[StyleText]
FontFace=#FontFace#
FontSize=#FontSizeM#
FontColor=#ColorTextPrimary#
StringAlign=Left
AntiAlias=1

; Small uppercase widget title (SYSTEM, NETWORK, ...)
[StyleTitle]
X=#Pad#
Y=#Pad#
FontSize=#FontSizeS#
FontWeight=600
FontColor=#ColorTextSecondary#
StringCase=Upper
InlineSetting=CharacterSpacing | 0.6 | 0.6

; Small secondary label (CPU, RAM, units, ...)
[StyleLabel]
FontSize=#FontSizeS#
FontColor=#ColorTextSecondary#

; Large primary numeric value
[StyleValue]
FontFace=#FontFaceNum#
FontWeight=#FontWeightNum#
FontSize=#FontSizeL#
FontColor=#ColorTextPrimary#

; Medium body text
[StyleBody]
FontSize=#FontSizeM#
FontColor=#ColorTextPrimary#

; Right-aligned anchor at the card's inner right edge.
; Keeps numbers from shifting when their width changes.
[StyleRight]
X=(#CardW#-#Pad#)
StringAlign=Right

; ---- Separator ----------------------------------------------
; Full-width hairline. Set Y in the meter.
[StyleSeparator]
X=#Pad#
Shape=Rectangle 0,0,(#CardW#-2*#Pad#),1 | Fill Color #ColorBorder# | StrokeWidth 0

; ---- Arrow icons (Shape) ------------------------------------
; Box is ArrowS x ArrowS. The 1px inset keeps round caps inside
; the meter bounds.
[StyleArrowDown]
Shape=Path ArrowShaft | Extend ArrowStroke
Shape2=Path ArrowHeadDown | Extend ArrowStroke
ArrowShaft=(#ArrowS#/2),1 | LineTo (#ArrowS#/2),(#ArrowS#-1)
ArrowHeadDown=1,(#ArrowS#/2) | LineTo (#ArrowS#/2),(#ArrowS#-1) | LineTo (#ArrowS#-1),(#ArrowS#/2)
ArrowStroke=StrokeWidth #ArrowStrokeW# | Stroke Color #ColorAccent# | Fill Color 0,0,0,0 | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round

[StyleArrowUp]
Shape=Path ArrowShaft | Extend ArrowStroke
Shape2=Path ArrowHeadUp | Extend ArrowStroke
ArrowShaft=(#ArrowS#/2),1 | LineTo (#ArrowS#/2),(#ArrowS#-1)
ArrowHeadUp=1,(#ArrowS#/2) | LineTo (#ArrowS#/2),1 | LineTo (#ArrowS#-1),(#ArrowS#/2)
ArrowStroke=StrokeWidth #ArrowStrokeW# | Stroke Color #ColorAccentDim# | Fill Color 0,0,0,0 | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round

; ---- Graph area ---------------------------------------------
[StyleLineGraph]
LineColor=#ColorAccent#
LineWidth=(1.25*#Scale#)
AutoScale=0
GraphStart=Right
AntiAlias=1

[StyleHistogram]
PrimaryColor=#ColorAccentSoft#
AutoScale=0
GraphStart=Right
AntiAlias=1
