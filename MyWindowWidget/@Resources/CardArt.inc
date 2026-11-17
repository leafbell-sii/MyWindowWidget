; =============================================================
;  MyWindowWidget - card art (concept themes)
;  Include it from the card background meter, right after the
;  StyleCard shape:
;
;    [MeterBg]
;    Meter=Shape
;    MeterStyle=StyleCard
;    @IncludeCardArt=#@#CardArt.inc
;
;  The sections below are then inserted right after MeterBg, so
;  they draw over the card colour and under everything else.
;  Themes without art leave CardTexture / CardTrim empty and
;  nothing is drawn.
;
;  The images are clipped to a rounded rectangle 1 px inside the
;  card border (Container), so the border stays visible and the
;  corners stay round. Both images use BgAlpha, so the Opacity
;  setting fades the art together with the card colour.
; =============================================================

; Mask only: a container meter is never drawn itself.
[MeterCardMask]
Meter=Shape
Shape=Rectangle 1,1,(#CardW#-2),(#CardH#-2),(#Radius#-1) | Fill Color 255,255,255,255 | StrokeWidth 0
DynamicVariables=1

; Tiled over the whole card. H is a safe upper bound instead of
; CardH: some skins compute CardH from other meters, which would
; need DynamicVariables=1, and that reloads the image from disk on
; every update. The container clips the rest.
[MeterCardTexture]
Meter=Image
ImageName=#CardTexture#
Container=MeterCardMask
Tile=1
W=#CardW#
H=(2*#CardW#)
ImageAlpha=#BgAlpha#

; Repeated along the top edge, inside the top padding.
[MeterCardTrim]
Meter=Image
ImageName=#CardTrim#
Container=MeterCardMask
Tile=1
X=0r
Y=0r
W=#CardW#
H=#CardTrimH#
ImageAlpha=#BgAlpha#
