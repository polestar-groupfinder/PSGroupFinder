#!/usr/bin/env python3
"""Draws PSGroupFinder's icons, line art, white on transparent.

Supersampled 8x then reduced, so the strokes stay smooth at 14-24 px.
Writes PSGroupFinder/Media/icon-group.tga (the finder), icon-invite.tga (two
people and a plus: Invite / Ask) and icon-whisper.tga (a speech bubble:
Whisper) and icon-gear.tga (a cog: the panel's settings), 64x64, 32-bit,
uncompressed.
Run from the repo root: python3 tools/make-icons.py (needs Pillow).
"""
import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

SS = 8
N = 64
C = N * SS
STROKE = 5.5


def px(v):
    return v * SS


def person(cx, head_y, head_r, rx, ry, gap, w):
    """Stroke mask and filled silhouette of one person (head + shoulders)."""
    stroke = Image.new("L", (C, C), 0)
    filled = Image.new("L", (C, C), 0)
    ds, df = ImageDraw.Draw(stroke), ImageDraw.Draw(filled)
    head = [cx - head_r, head_y - head_r, cx + head_r, head_y + head_r]
    ds.ellipse(head, outline=255, width=int(w))
    df.ellipse(head, fill=255)
    sy = head_y + head_r + gap + ry
    box = [cx - rx, sy - ry, cx + rx, sy + ry]
    ds.arc(box, 180, 360, fill=255, width=int(w))
    df.pieslice(box, 180, 360, fill=255)
    for a in (180, 360):  # round caps at the shoulders' ends
        x = cx + (rx - w / 2) * math.cos(math.radians(a))
        ds.ellipse([x - w / 2, sy - w / 2, x + w / 2, sy + w / 2], fill=255)
    return stroke, filled


def group(w):
    back, _ = person(px(45), px(17), px(8.5), px(15), px(14), px(3.5), w)
    front, front_fill = person(px(25), px(21), px(10.5), px(19), px(17), px(4), w)
    # The front person hides the one behind, with a small gap around it.
    hole = front_fill.filter(ImageFilter.MaxFilter(int(w * 1.6) | 1))
    return ImageChops.lighter(ImageChops.subtract(back, hole), front)


def plus(d, cx, cy, arm, w):
    d.line([cx - arm, cy, cx + arm, cy], fill=255, width=int(w))
    d.line([cx, cy - arm, cx, cy + arm], fill=255, width=int(w))
    for x, y in ((cx - arm, cy), (cx + arm, cy), (cx, cy - arm), (cx, cy + arm)):
        d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=255)


def invite(w):
    """Two people (narrower, to the left) and a plus at the top right."""
    back, _ = person(px(32), px(22), px(6.5), px(11), px(11), px(3), w)
    front, front_fill = person(px(18), px(25), px(8.5), px(15), px(14), px(3), w)
    hole = front_fill.filter(ImageFilter.MaxFilter(int(w * 1.6) | 1))
    img = ImageChops.lighter(ImageChops.subtract(back, hole), front)
    d = ImageDraw.Draw(img)
    plus(d, px(52), px(16), px(8), w)
    return img


def whisper(w):
    """A speech bubble: a rounded box with a tail and three dots."""
    img = Image.new("L", (C, C), 0)
    d = ImageDraw.Draw(img)
    box = [px(6), px(10), px(58), px(46)]
    d.rounded_rectangle(box, radius=px(11), outline=255, width=int(w))
    # The tail, bottom left: cut the outline, then draw two strokes.
    d.polygon([(px(16), px(43)), (px(28), px(43)), (px(16), px(56))], fill=0)
    for a, b in (((px(16), px(44)), (px(16), px(56))), ((px(16), px(56)), (px(28), px(45)))):
        d.line([a, b], fill=255, width=int(w))
        for x, y in (a, b):
            d.ellipse([x - w / 2, y - w / 2, x + w / 2, y + w / 2], fill=255)
    for x in (22, 32, 42):
        r = px(3.4)
        d.ellipse([px(x) - r, px(28) - r, px(x) + r, px(28) + r], fill=255)
    return img


def gear(w):
    """A cog: eight teeth around a ring, a hole in the middle."""
    import math as m
    img = Image.new("L", (C, C), 0)
    d = ImageDraw.Draw(img)
    cx = cy = px(32)
    r_out, r_in = px(21), px(16)
    pts = []
    teeth = 8
    for i in range(teeth * 4):
        a = i * m.pi * 2 / (teeth * 4)
        r = r_out if (i % 4) in (1, 2) else r_in
        pts.append((cx + r * m.cos(a), cy + r * m.sin(a)))
    d.polygon(pts, fill=255)
    # Hollow the body, then the hole.
    inner = Image.new("L", (C, C), 0)
    ImageDraw.Draw(inner).polygon(pts, fill=255)
    inner = inner.filter(ImageFilter.MinFilter(int(w * 1.6) | 1))
    img = ImageChops.subtract(img, inner)
    d = ImageDraw.Draw(img)
    hr = px(7)
    d.ellipse([cx - hr, cy - hr, cx + hr, cy + hr], outline=255, width=int(w))
    return img


def save(mask, name):
    alpha = mask.resize((N, N), Image.LANCZOS)
    img = Image.new("RGBA", (N, N), (255, 255, 255, 0))
    img.putalpha(alpha)
    out = Path(__file__).resolve().parent.parent / "PSGroupFinder" / "Media" / name
    img.save(out, compression=None)
    print(out)


def main():
    save(group(px(STROKE)), "icon-group.tga")
    save(invite(px(STROKE)), "icon-invite.tga")
    save(whisper(px(STROKE)), "icon-whisper.tga")
    save(gear(px(STROKE)), "icon-gear.tga")


if __name__ == "__main__":
    main()
