"""Generates the card art used by the concept themes (Christmas, Cafe).

Writes into MyWindowWidget/@Resources/Images/<Theme>/:
  Texture.png  seamless tile, transparent with soft detail. Drawn over the
               card colour (ColorBg) so opacity / hover keep working.
  Trim.png     horizontal tile for the top edge of the card (string lights,
               cafe awning). Its height must match CardTrimH in the theme.

Everything is drawn at SS x size and downsampled for anti-aliasing.
Seeded, so re-running gives the same files.

  python -m pip install pillow
  python tools/dev/make-concept-art.py
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

SS = 4
ROOT = os.path.join(os.path.dirname(__file__), '..', '..', 'MyWindowWidget', '@Resources', 'Images')


def canvas(w, h):
    return Image.new('RGBA', (w * SS, h * SS), (0, 0, 0, 0))


def finish(img, path):
    w, h = img.size[0] // SS, img.size[1] // SS
    img = img.resize((w, h), Image.LANCZOS)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)
    print('wrote', os.path.relpath(path), img.size)


def wrapped(draw_fn, w, h, x, y, *args):
    """Draws a shape at (x, y) and at its wrapped copies so the tile is seamless."""
    for dx in (-w, 0, w):
        for dy in (-h, 0, h):
            draw_fn(x + dx, y + dy, *args)


# ---------------------------------------------------------------- Christmas

def snowflake(d, cx, cy, r, alpha, width):
    col = (255, 255, 255, alpha)
    for k in range(6):
        a = math.radians(60 * k + 90)
        ex, ey = cx + r * math.cos(a), cy - r * math.sin(a)
        d.line([(cx, cy), (ex, ey)], fill=col, width=width)
        # Two small barbs on each arm.
        for t, br in ((0.55, 0.32), (0.8, 0.2)):
            px, py = cx + r * t * math.cos(a), cy - r * t * math.sin(a)
            for s in (-1, 1):
                b = a + s * math.radians(45)
                d.line([(px, py), (px + r * br * math.cos(b), py - r * br * math.sin(b))], fill=col, width=width)


def christmas_texture(path):
    W = H = 224
    img = canvas(W, H)
    d = ImageDraw.Draw(img)
    rnd = random.Random(1225)
    # Fine snow specks.
    for _ in range(70):
        x, y = rnd.uniform(0, W) * SS, rnd.uniform(0, H) * SS
        r = rnd.uniform(0.5, 1.3) * SS
        a = rnd.randint(18, 46)
        wrapped(lambda px, py: d.ellipse([px - r, py - r, px + r, py + r], fill=(255, 255, 255, a)),
                W * SS, H * SS, x, y)
    # A few faint snowflakes, spread out so the tile does not look busy.
    flakes = [(40, 50, 9), (160, 34, 6), (110, 120, 11), (24, 172, 6), (190, 150, 8), (80, 206, 5)]
    for fx, fy, fr in flakes:
        a = rnd.randint(26, 40)
        wrapped(lambda px, py: snowflake(d, px, py, fr * SS, a, max(1, int(0.9 * SS))),
                W * SS, H * SS, fx * SS, fy * SS)
    finish(img, path)


def christmas_trim(path):
    # One tile = 4 bulbs on a sagging wire. H must match CardTrimH.
    W, H = 160, 16
    img = canvas(W, H)
    glow = canvas(W, H)
    d = ImageDraw.Draw(img)
    g = ImageDraw.Draw(glow)
    colors = [(232, 74, 66), (246, 196, 84), (96, 186, 112), (110, 160, 232)]
    seg = W / 4
    wire = (30, 22, 18, 230)
    for i, col in enumerate(colors):
        x0 = i * seg
        pts = []
        for t in range(0, 21):
            u = t / 20
            pts.append(((x0 + u * seg) * SS, (1.6 + 3.2 * math.sin(math.pi * u)) * SS))
        d.line(pts, fill=wire, width=int(1.1 * SS), joint='curve')
        # Bulb hangs from the lowest point of the sag.
        bx, by = (x0 + seg / 2) * SS, 4.8 * SS
        g.ellipse([bx - 7 * SS, by + 1 * SS, bx + 7 * SS, by + 15 * SS], fill=col + (110,))
        d.rounded_rectangle([bx - 1.6 * SS, by - 0.4 * SS, bx + 1.6 * SS, by + 2.4 * SS], radius=0.6 * SS,
                            fill=(70, 62, 50, 255))
        d.ellipse([bx - 2.9 * SS, by + 1.8 * SS, bx + 2.9 * SS, by + 10.6 * SS], fill=col + (255,))
        d.ellipse([bx - 1.6 * SS, by + 3.0 * SS, bx - 0.2 * SS, by + 6.0 * SS], fill=(255, 255, 255, 150))
    glow = glow.filter(ImageFilter.GaussianBlur(3.5 * SS))
    finish(Image.alpha_composite(glow, img), path)


# ---------------------------------------------------------------- Cafe

def cafe_texture(path):
    W = H = 320
    img = canvas(W, H)
    d = ImageDraw.Draw(img)
    rnd = random.Random(1776)
    brown = (110, 70, 40)
    # Paper grain: many tiny specks, light and dark.
    for _ in range(900):
        x, y = rnd.uniform(0, W) * SS, rnd.uniform(0, H) * SS
        r = rnd.uniform(0.35, 0.9) * SS
        col = brown + (rnd.randint(8, 22),) if rnd.random() < 0.7 else (255, 255, 255, rnd.randint(20, 50))
        wrapped(lambda px, py: d.ellipse([px - r, py - r, px + r, py + r], fill=col), W * SS, H * SS, x, y)
    # Coffee-cup ring: uneven width, slightly broken, darker edge.
    ring = canvas(W, H)
    rd = ImageDraw.Draw(ring)
    cx, cy, R = 230 * SS, 214 * SS, 50 * SS
    for k in range(360):
        a0 = math.radians(k)
        if 200 < k < 228:
            continue
        wobble = 1 + 0.03 * math.sin(3 * a0) + 0.015 * math.sin(7 * a0)
        wid = (2.2 + 1.4 * math.sin(2 * a0 + 0.6)) * SS
        x, y = cx + R * wobble * math.cos(a0), cy + R * wobble * math.sin(a0)
        wrapped(lambda px, py: rd.ellipse([px - wid, py - wid, px + wid, py + wid], fill=brown + (34,)),
                W * SS, H * SS, x, y)
    ring = ring.filter(ImageFilter.GaussianBlur(0.8 * SS))
    img = Image.alpha_composite(img, ring)
    d = ImageDraw.Draw(img)
    # Two faint coffee beans.
    for bx, by, ang in ((70 * SS, 80 * SS, 30), (92 * SS, 98 * SS, -20)):
        bean = Image.new('RGBA', (28 * SS, 20 * SS), (0, 0, 0, 0))
        bd = ImageDraw.Draw(bean)
        bd.ellipse([2 * SS, 2 * SS, 26 * SS, 18 * SS], fill=brown + (26,))
        bd.arc([6 * SS, -4 * SS, 22 * SS, 16 * SS], 40, 140, fill=brown + (40,), width=int(1.2 * SS))
        bd.arc([6 * SS, 4 * SS, 22 * SS, 24 * SS], 220, 320, fill=brown + (40,), width=int(1.2 * SS))
        bean = bean.rotate(ang, resample=Image.BICUBIC, expand=True)
        img.alpha_composite(bean, (int(bx - bean.size[0] / 2), int(by - bean.size[1] / 2)))
    finish(img, path)


def cafe_trim(path):
    # Striped awning with a scalloped edge. H must match CardTrimH.
    W, H = 32, 14
    img = canvas(W, H)
    d = ImageDraw.Draw(img)
    stripe = W / 2
    body = 8.5
    for i, col in enumerate([(176, 96, 62, 255), (250, 242, 228, 255)]):
        x0 = i * stripe
        d.rectangle([x0 * SS, 0, (x0 + stripe) * SS, body * SS], fill=col)
        d.ellipse([x0 * SS, (body - stripe / 2) * SS, (x0 + stripe) * SS, (body + stripe / 2) * SS], fill=col)
    # Thin shadow line under the valance.
    shadow = canvas(W, H)
    sd = ImageDraw.Draw(shadow)
    for i in range(2):
        x0 = i * stripe
        sd.ellipse([x0 * SS, (body - stripe / 2 + 1.2) * SS, (x0 + stripe) * SS, (body + stripe / 2 + 1.2) * SS],
                   fill=(60, 36, 20, 70))
    shadow = shadow.filter(ImageFilter.GaussianBlur(0.6 * SS))
    finish(Image.alpha_composite(shadow, img), path)


if __name__ == '__main__':
    christmas_texture(os.path.join(ROOT, 'Christmas', 'Texture.png'))
    christmas_trim(os.path.join(ROOT, 'Christmas', 'Trim.png'))
    cafe_texture(os.path.join(ROOT, 'Cafe', 'Texture.png'))
    cafe_trim(os.path.join(ROOT, 'Cafe', 'Trim.png'))
