#!/usr/bin/env python3
"""Draws PSGroupFinder's icon: two line-art people, white on transparent.

Supersampled 8x then reduced, so the strokes stay smooth at 14-24 px.
Writes PSGroupFinder/Media/icon-group.tga (64x64, 32-bit, uncompressed).
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


def main():
    alpha = group(px(STROKE)).resize((N, N), Image.LANCZOS)
    img = Image.new("RGBA", (N, N), (255, 255, 255, 0))
    img.putalpha(alpha)
    out = Path(__file__).resolve().parent.parent / "PSGroupFinder" / "Media" / "icon-group.tga"
    img.save(out, compression=None)
    print(out)


if __name__ == "__main__":
    main()
