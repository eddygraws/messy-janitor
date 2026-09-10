#!/usr/bin/env python3
"""Bake Windows ICO + 256 PNG from the branding mop mark."""

from __future__ import annotations

import os
import struct
import zlib

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "branding")
OUT_PNG = os.path.join(ROOT, "icon_256.png")
OUT_ICO = os.path.join(ROOT, "icon.ico")
SRC = 256
SIZES = (16, 32, 48, 64, 128, 256)


def png_bytes(w: int, h: int, px: list[int]) -> bytes:
    raw = b""
    for y in range(h):
        raw += b"\x00"
        raw += bytes(px[y * w * 4 : (y + 1) * w * 4])

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")


def put(px: list[int], n: int, x: int, y: int, r: int, g: int, b: int, a: int = 255) -> None:
    if 0 <= x < n and 0 <= y < n and a > 0:
        i = (y * n + x) * 4
        px[i : i + 4] = [r, g, b, a]


def inside_round_rect(x: float, y: float, x0: float, y0: float, x1: float, y1: float, rad: float) -> bool:
    if x < x0 or x >= x1 or y < y0 or y >= y1:
        return False
    r = max(0.0, rad)
    cx = x + 0.5
    cy = y + 0.5
    if cx < x0 + r and cy < y0 + r:
        return (cx - (x0 + r)) ** 2 + (cy - (y0 + r)) ** 2 <= r * r
    if cx >= x1 - r and cy < y0 + r:
        return (cx - (x1 - r)) ** 2 + (cy - (y0 + r)) ** 2 <= r * r
    if cx < x0 + r and cy >= y1 - r:
        return (cx - (x0 + r)) ** 2 + (cy - (y1 - r)) ** 2 <= r * r
    if cx >= x1 - r and cy >= y1 - r:
        return (cx - (x1 - r)) ** 2 + (cy - (y1 - r)) ** 2 <= r * r
    return True


def fill_round_rect(px, n, x0, y0, x1, y1, rad, c) -> None:
    for y in range(max(0, int(y0)), min(n, int(y1) + 1)):
        for x in range(max(0, int(x0)), min(n, int(x1) + 1)):
            if inside_round_rect(x, y, x0, y0, x1, y1, rad):
                put(px, n, x, y, *c)


def fill_rect(px, n, x0, y0, x1, y1, c) -> None:
    fill_round_rect(px, n, x0, y0, x1, y1, 0.0, c)


def fill_disc(px, n, cx, cy, rad, c) -> None:
    r2 = rad * rad
    for y in range(int(cy - rad) - 1, int(cy + rad) + 2):
        for x in range(int(cx - rad) - 1, int(cx + rad) + 2):
            if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r2:
                put(px, n, x, y, *c)


def draw_src() -> list[int]:
    n = SRC
    px = [0] * (n * n * 4)
    fill_round_rect(px, n, 0, 0, 256, 256, 28, (26, 36, 32, 255))
    fill_round_rect(px, n, 10, 10, 246, 246, 22, (232, 208, 106, 255))
    fill_round_rect(px, n, 16, 16, 240, 240, 18, (36, 51, 44, 255))
    fill_round_rect(px, n, 78, 168, 178, 196, 6, (74, 109, 122, 255))
    fill_round_rect(px, n, 86, 160, 170, 174, 4, (106, 140, 153, 255))
    fill_round_rect(px, n, 118, 52, 132, 170, 4, (196, 162, 74, 255))
    for y in range(58, 95):
        t = (y - 58) / 36.0
        x0 = 88 + (98 - 88) * t
        x1 = 180 + (170 - 180) * t
        fill_rect(px, n, x0, y, x1, y + 1, (124, 179, 137, 255))
    fill_disc(px, n, 64, 196, 10, (232, 208, 106, 255))
    fill_disc(px, n, 192, 196, 10, (232, 208, 106, 255))
    return px


def scale_nn(src: list[int], src_n: int, dst_n: int) -> list[int]:
    if dst_n == src_n:
        return src[:]
    dst = [0] * (dst_n * dst_n * 4)
    for y in range(dst_n):
        sy = y * src_n // dst_n
        for x in range(dst_n):
            sx = x * src_n // dst_n
            si = (sy * src_n + sx) * 4
            di = (y * dst_n + x) * 4
            dst[di : di + 4] = src[si : si + 4]
    return dst


def write_ico(path: str, images: list[tuple[int, bytes]]) -> None:
    count = len(images)
    offset = 6 + 16 * count
    entries = b""
    blobs = b""
    for size, data in images:
        w = 0 if size >= 256 else size
        h = 0 if size >= 256 else size
        entries += struct.pack("<BBBBHHII", w, h, 0, 0, 1, 32, len(data), offset)
        blobs += data
        offset += len(data)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(struct.pack("<HHH", 0, 1, count) + entries + blobs)


def main() -> None:
    src = draw_src()
    os.makedirs(ROOT, exist_ok=True)
    with open(OUT_PNG, "wb") as f:
        f.write(png_bytes(SRC, SRC, src))
    packed: list[tuple[int, bytes]] = []
    for size in SIZES:
        packed.append((size, png_bytes(size, size, scale_nn(src, SRC, size))))
    write_ico(OUT_ICO, packed)
    print("wrote", OUT_PNG)
    print("wrote", OUT_ICO)


if __name__ == "__main__":
    main()
