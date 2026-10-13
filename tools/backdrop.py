#!/usr/bin/env python3
"""Writes a soft, colorful wallpaper-style PNG used behind screenshot windows.

The glass variants show whatever is behind them; a fixed backdrop keeps screenshots identical
from run to run and never captures anything personal. Standard library only.

Usage: python3 tools/backdrop.py OUT.png [WIDTH HEIGHT]
"""

import math
import struct
import sys
import zlib

# (x, y) as fractions of the image, radius as a fraction of the width, color in sRGB.
BLOBS = [
    (0.18, 0.25, 0.42, (0x2E, 0x6B, 0xFF)),  # blue
    (0.78, 0.18, 0.38, (0xB1, 0x4C, 0xF0)),  # violet
    (0.70, 0.85, 0.45, (0xFF, 0x7A, 0x45)),  # warm orange
    (0.15, 0.90, 0.35, (0x1F, 0xC8, 0xC0)),  # teal
    (0.48, 0.52, 0.30, (0xFF, 0x4F, 0x8B)),  # pink
]
BASE = (0x14, 0x16, 0x2E)  # deep navy


def pixel(x, y, w, h):
    r, g, b = (float(c) for c in BASE)
    for bx, by, br, color in BLOBS:
        dx, dy = x - bx * w, y - by * h
        weight = math.exp(-(dx * dx + dy * dy) / (2 * (br * w * 0.5) ** 2))
        r += (color[0] - r) * weight
        g += (color[1] - g) * weight
        b += (color[2] - b) * weight
    return bytes((min(255, int(r)), min(255, int(g)), min(255, int(b))))


def write_png(path, w, h):
    rows = []
    for y in range(h):
        rows.append(b"\x00" + b"".join(pixel(x, y, w, h) for x in range(w)))
    raw = zlib.compress(b"".join(rows), 9)

    def chunk(kind, data):
        body = kind + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)))
        f.write(chunk(b"IDAT", raw))
        f.write(chunk(b"IEND", b""))


if __name__ == "__main__":
    if len(sys.argv) not in (2, 4):
        sys.exit(__doc__.strip().splitlines()[-1])
    width, height = (int(sys.argv[2]), int(sys.argv[3])) if len(sys.argv) == 4 else (1200, 840)
    write_png(sys.argv[1], width, height)
