"""Prints the FontCapTop / FontAscent / FontDescent values (px per pt) that
Variables.inc and the theme files use to line up text of different sizes.

DirectWrite sizes a text line from the font's OS/2 winAscent / winDescent
(1 pt = 4/3 px), so:
  Ascent  = winAscent / unitsPerEm * 4/3      top of box -> baseline
  Descent = winDescent / unitsPerEm * 4/3     baseline -> bottom of box
  CapTop  = (winAscent - capHeight) / unitsPerEm * 4/3

  python -m pip install fonttools
  python tools/dev/font-metrics.py MyWindowWidget/@Resources/Fonts/*.ttf
"""
import sys

from fontTools.ttLib import TTFont

for path in sys.argv[1:]:
    f = TTFont(path)
    os2, em = f['OS/2'], f['head'].unitsPerEm
    k = 4 / 3 / em
    cap = getattr(os2, 'sCapHeight', 0) or 0.7 * em
    print(f"{path}\n  family={f['name'].getDebugName(16) or f['name'].getDebugName(1)}"
          f"  CapTop={(os2.usWinAscent - cap) * k:.3f}"
          f"  Ascent={os2.usWinAscent * k:.3f}"
          f"  Descent={os2.usWinDescent * k:.3f}"
          f"  LineH={(os2.usWinAscent + os2.usWinDescent) * k:.3f}")
