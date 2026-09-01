#!/usr/bin/env python3
"""Bake a 32px HUD icon atlas (8x2) to res://assets/ui/hud_icons.png."""

from __future__ import annotations

import os
import struct
import zlib

TILE = 32
COLS = 8
ROWS = 2
W = TILE * COLS
H = TILE * ROWS
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "ui", "hud_icons.png")


def png(path: str, w: int, h: int, px: list[int]) -> None:
    raw = b""
    for y in range(h):
        raw += b"\x00"
        for x in range(w):
            i = (y * w + x) * 4
            raw += bytes(px[i : i + 4])

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(data)


def put(px: list[int], x: int, y: int, r: int, g: int, b: int, a: int = 255) -> None:
    if 0 <= x < W and 0 <= y < H and a > 0:
        i = (y * W + x) * 4
        px[i : i + 4] = [r, g, b, a]


def rect(px, x0, y0, x1, y1, c) -> None:
    for y in range(y0, y1):
        for x in range(x0, x1):
            put(px, x, y, *c)


def disc(px, cx, cy, rad, c) -> None:
    r2 = rad * rad
    for y in range(cy - rad, cy + rad + 1):
        for x in range(cx - rad, cx + rad + 1):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r2:
                put(px, x, y, *c)


def outline_disc(px, cx, cy, rad, c, oc=(20, 16, 12, 255)) -> None:
    disc(px, cx, cy, rad + 1, oc)
    disc(px, cx, cy, rad, c)


def mop(px, ox, oy) -> None:
    rect(px, ox + 14, oy + 4, ox + 18, oy + 22, (40, 32, 24, 255))
    rect(px, ox + 8, oy + 20, ox + 24, oy + 26, (70, 160, 90, 255))
    rect(px, ox + 7, oy + 19, ox + 25, oy + 21, (30, 24, 18, 255))
    rect(px, ox + 9, oy + 24, ox + 23, oy + 28, (90, 190, 120, 255))


def broom(px, ox, oy) -> None:
    rect(px, ox + 15, oy + 4, ox + 18, oy + 18, (90, 70, 40, 255))
    rect(px, ox + 8, oy + 17, ox + 24, oy + 28, (180, 150, 70, 255))
    for x in range(9, 24, 3):
        rect(px, ox + x, oy + 18, ox + x + 1, oy + 27, (120, 90, 40, 255))


def brush(px, ox, oy) -> None:
    rect(px, ox + 13, oy + 5, ox + 19, oy + 16, (70, 90, 160, 255))
    rect(px, ox + 10, oy + 15, ox + 22, oy + 20, (40, 32, 28, 255))
    rect(px, ox + 9, oy + 19, ox + 23, oy + 27, (200, 170, 90, 255))


def spray(px, ox, oy) -> None:
    rect(px, ox + 12, oy + 8, ox + 20, oy + 26, (80, 150, 190, 255))
    rect(px, ox + 14, oy + 4, ox + 18, oy + 9, (50, 50, 55, 255))
    disc(px, ox + 22, oy + 7, 2, (180, 220, 255, 200))
    disc(px, ox + 25, oy + 5, 2, (180, 220, 255, 140))


def tweezers(px, ox, oy) -> None:
    rect(px, ox + 10, oy + 6, ox + 13, oy + 26, (180, 190, 200, 255))
    rect(px, ox + 19, oy + 6, ox + 22, oy + 26, (180, 190, 200, 255))
    rect(px, ox + 10, oy + 5, ox + 22, oy + 8, (140, 150, 160, 255))


def heart(px, ox, oy) -> None:
    outline_disc(px, ox + 11, oy + 13, 6, (220, 50, 70, 255))
    outline_disc(px, ox + 20, oy + 13, 6, (220, 50, 70, 255))
    rect(px, ox + 8, oy + 14, ox + 24, oy + 22, (220, 50, 70, 255))
    for i in range(8):
        rect(px, ox + 10 + i, oy + 21 + i // 2, ox + 22 - i, oy + 22 + i // 2, (220, 50, 70, 255))


def coin(px, ox, oy) -> None:
    outline_disc(px, ox + 16, oy + 16, 11, (240, 190, 50, 255), (80, 50, 10, 255))
    outline_disc(px, ox + 16, oy + 16, 7, (255, 220, 90, 255), (180, 120, 20, 255))


def job(px, ox, oy) -> None:
    rect(px, ox + 7, oy + 10, ox + 25, oy + 26, (210, 190, 140, 255))
    rect(px, ox + 6, oy + 9, ox + 26, oy + 11, (90, 70, 40, 255))
    rect(px, ox + 13, oy + 7, ox + 19, oy + 11, (70, 55, 35, 255))


def gold(px, ox, oy) -> None:
    disc(px, ox + 16, oy + 18, 10, (240, 180, 40, 255))
    rect(px, ox + 10, oy + 6, ox + 22, oy + 12, (220, 160, 30, 255))
    rect(px, ox + 8, oy + 4, ox + 24, oy + 8, (255, 210, 70, 255))


def silver(px, ox, oy) -> None:
    disc(px, ox + 16, oy + 18, 10, (190, 200, 210, 255))
    rect(px, ox + 10, oy + 6, ox + 22, oy + 12, (160, 170, 180, 255))
    rect(px, ox + 8, oy + 4, ox + 24, oy + 8, (230, 235, 240, 255))


def bronze(px, ox, oy) -> None:
    disc(px, ox + 16, oy + 18, 10, (180, 110, 50, 255))
    rect(px, ox + 10, oy + 6, ox + 22, oy + 12, (150, 85, 40, 255))
    rect(px, ox + 8, oy + 4, ox + 24, oy + 8, (210, 140, 70, 255))


def bucket(px, ox, oy) -> None:
    rect(px, ox + 9, oy + 12, ox + 23, oy + 26, (70, 80, 95, 255))
    rect(px, ox + 10, oy + 14, ox + 22, oy + 20, (70, 150, 210, 255))
    rect(px, ox + 8, oy + 10, ox + 24, oy + 13, (50, 55, 65, 255))


def trash(px, ox, oy) -> None:
    rect(px, ox + 9, oy + 10, ox + 23, oy + 26, (70, 85, 70, 255))
    rect(px, ox + 8, oy + 8, ox + 24, oy + 11, (50, 60, 50, 255))
    rect(px, ox + 14, oy + 5, ox + 18, oy + 9, (50, 60, 50, 255))


def warning(px, ox, oy) -> None:
    for i in range(14):
        rect(px, ox + 16 - i // 2, oy + 5 + i, ox + 17 + i // 2, oy + 6 + i, (240, 190, 40, 255))
    rect(px, ox + 15, oy + 12, ox + 17, oy + 20, (30, 24, 16, 255))
    rect(px, ox + 15, oy + 22, ox + 17, oy + 24, (30, 24, 16, 255))


def empty_cell(_px, _ox, _oy) -> None:
    pass


DRAWERS = [
    mop, broom, brush, spray, tweezers, heart, coin, job,
    gold, silver, bronze, bucket, trash, warning, empty_cell, empty_cell,
]


def main() -> None:
    px = [0] * (W * H * 4)
    for i, fn in enumerate(DRAWERS):
        ox = (i % COLS) * TILE
        oy = (i // COLS) * TILE
        fn(px, ox, oy)
    png(OUT, W, H, px)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
