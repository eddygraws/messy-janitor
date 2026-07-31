#!/usr/bin/env python3
"""Generate flat-shaded / hand-painted-style tile albedo textures for Godot toon materials.

Examples:
  python tools/generate_tile_texture.py --pattern floor --output textures/generated/floor_demo.png
  python tools/generate_tile_texture.py --pattern wall_brick --main-color 120,110,100 --seed 42
  python tools/generate_tile_texture.py --batch
"""

from __future__ import annotations

import argparse
import hashlib
import random
import sys
from pathlib import Path
from typing import Iterable, Sequence

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

# Project root (…/messy-janitor)
ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUT_DIR = ROOT / "textures" / "generated"

# Default Overcooked-ish kitchen clay palette
DEFAULT_MAIN = (196, 182, 158)
DEFAULT_GROUT = (138, 126, 108)
DEFAULT_STAIN = (168, 156, 134)

# Campaign-ish palettes for --batch (name, main, grout, stain, pattern)
BATCH_PALETTES: list[dict] = [
    {
        "name": "floor_kitchen_clay",
        "pattern": "floor",
        "main": (196, 182, 158),
        "grout": (138, 126, 108),
        "stain": (168, 156, 134),
        "seed": 7,
    },
    {
        "name": "floor_mold_green",
        "pattern": "floor",
        "main": (92, 128, 98),
        "grout": (58, 82, 64),
        "stain": (72, 108, 80),
        "seed": 11,
    },
    {
        "name": "floor_broom_wood",
        "pattern": "floor",
        "main": (168, 128, 86),
        "grout": (110, 82, 54),
        "stain": (148, 112, 74),
        "seed": 19,
    },
    {
        "name": "floor_slime_teal",
        "pattern": "floor",
        "main": (70, 130, 122),
        "grout": (42, 86, 80),
        "stain": (58, 112, 104),
        "seed": 23,
    },
    {
        "name": "floor_brush_purple",
        "pattern": "floor",
        "main": (148, 108, 168),
        "grout": (96, 68, 112),
        "stain": (128, 92, 148),
        "seed": 29,
    },
    {
        "name": "floor_check_dark",
        "pattern": "floor",
        "main": (62, 64, 78),
        "grout": (36, 38, 48),
        "stain": (78, 80, 96),
        "seed": 31,
    },
    {
        "name": "wall_plaster_warm",
        "pattern": "wall_brick",
        "main": (210, 198, 182),
        "grout": (150, 140, 128),
        "stain": (188, 176, 160),
        "seed": 41,
    },
    {
        "name": "wall_brick_garage",
        "pattern": "wall_brick",
        "main": (168, 112, 92),
        "grout": (96, 72, 62),
        "stain": (148, 98, 80),
        "seed": 47,
    },
    {
        "name": "wall_brick_mold",
        "pattern": "wall_brick",
        "main": (98, 132, 108),
        "grout": (62, 88, 72),
        "stain": (80, 118, 92),
        "seed": 53,
    },
    {
        "name": "wall_brick_ritual",
        "pattern": "wall_brick",
        "main": (118, 72, 128),
        "grout": (72, 42, 80),
        "stain": (102, 62, 112),
        "seed": 59,
    },
]


def parse_rgb(text: str) -> tuple[int, int, int]:
    parts = [p.strip() for p in text.replace(" ", "").split(",")]
    if len(parts) != 3:
        raise argparse.ArgumentTypeError(f"Expected R,G,B got {text!r}")
    rgb = tuple(int(p) for p in parts)
    for c in rgb:
        if c < 0 or c > 255:
            raise argparse.ArgumentTypeError(f"Channel out of range in {text!r}")
    return rgb  # type: ignore[return-value]


def _shift_color(color: tuple[int, int, int], delta: int) -> tuple[int, int, int]:
    return tuple(max(0, min(255, c + delta)) for c in color)  # type: ignore[return-value]


def _make_stain_mask(
    size: int,
    num_blobs: int,
    threshold: float = 0.35,
    blur: float = 1.5,
) -> np.ndarray:
    """Seamless wrap-around blobs, quantized to hard toon edges."""
    stain_layer = np.zeros((size, size), dtype=np.float32)
    yy, xx = np.mgrid[0:size, 0:size]
    for _ in range(num_blobs):
        cx, cy = random.uniform(0, size), random.uniform(0, size)
        r = random.uniform(size * 0.03, size * 0.09)
        strength = random.uniform(0.3, 0.7)
        for ox in (-size, 0, size):
            for oy in (-size, 0, size):
                d = np.sqrt((xx - (cx + ox)) ** 2 + (yy - (cy + oy)) ** 2)
                mask = np.clip(1.0 - d / r, 0, 1) ** 2
                stain_layer += mask * strength
    stain_layer = np.clip(stain_layer, 0, 1)
    stain_layer = np.where(stain_layer > threshold, 1.0, 0.0)
    stain_img = Image.fromarray((stain_layer * 255).astype(np.uint8)).filter(
        ImageFilter.GaussianBlur(blur)
    )
    return np.array(stain_img).astype(np.float32) / 255.0


def _apply_stains(
    img: Image.Image,
    stain_color: tuple[int, int, int],
    num_blobs: int,
    strength: float = 0.5,
) -> Image.Image:
    size = img.size[0]
    stain_mask = _make_stain_mask(size, num_blobs)
    base_arr = np.array(img).astype(np.float32)
    stain_arr = np.array(stain_color, dtype=np.float32)
    blended = base_arr * (1.0 - stain_mask[..., None] * strength) + stain_arr * (
        stain_mask[..., None] * strength
    )
    return Image.fromarray(blended.astype(np.uint8))


def _paste_tile_variation(
    img: Image.Image,
    main_color: tuple[int, int, int],
    x0: int,
    y0: int,
    x1: int,
    y1: int,
    blend: float = 0.25,
) -> None:
    if x1 <= x0 or y1 <= y0:
        return
    variation = random.randint(-6, 6)
    color = _shift_color(main_color, variation)
    overlay = Image.new("RGB", (x1 - x0, y1 - y0), color)
    cropped = img.crop((x0, y0, x1, y1))
    img.paste(Image.blend(cropped, overlay, blend), (x0, y0))


def generate_floor(
    size: int,
    tiles_per_texture: int,
    grout_thickness: int,
    main_color: tuple[int, int, int],
    grout_color: tuple[int, int, int],
    stain_color: tuple[int, int, int],
    num_blobs: int = 26,
) -> Image.Image:
    tile_size = size // tiles_per_texture
    img = Image.new("RGB", (size, size), main_color)
    draw = ImageDraw.Draw(img)

    half = grout_thickness // 2
    for i in range(tiles_per_texture + 1):
        x = i * tile_size
        draw.rectangle([x - half, 0, x + half, size], fill=grout_color)
        y = i * tile_size
        draw.rectangle([0, y - half, size, y + half], fill=grout_color)

    img = _apply_stains(img, stain_color, num_blobs)

    g = grout_thickness
    for ty in range(tiles_per_texture):
        for tx in range(tiles_per_texture):
            x0 = tx * tile_size + g
            y0 = ty * tile_size + g
            x1 = (tx + 1) * tile_size - g
            y1 = (ty + 1) * tile_size - g
            _paste_tile_variation(img, main_color, x0, y0, x1, y1)

    return img


def generate_wall_brick(
    size: int,
    tiles_per_texture: int,
    grout_thickness: int,
    main_color: tuple[int, int, int],
    grout_color: tuple[int, int, int],
    stain_color: tuple[int, int, int],
    num_blobs: int = 22,
) -> Image.Image:
    """Running-bond brick: every odd row offset by half a brick (seamless wrap)."""
    cols = tiles_per_texture
    # Slightly shorter bricks look more wall-like
    rows = max(tiles_per_texture + 1, int(tiles_per_texture * 1.25))
    brick_w = size // cols
    brick_h = size // rows
    half_g = grout_thickness // 2

    img = Image.new("RGB", (size, size), grout_color)
    draw = ImageDraw.Draw(img)

    for row in range(rows + 1):  # +1 covers wrap for odd offset rows
        y0 = (row % rows) * brick_h
        y1 = y0 + brick_h
        offset = (brick_w // 2) if (row % 2) == 1 else 0
        # Extra bricks when offset so wrap covers full width
        for col in range(-1, cols + 1):
            x0 = col * brick_w + offset
            x1 = x0 + brick_w
            # Fill brick body inset from grout
            ix0 = x0 + half_g
            iy0 = y0 + half_g
            ix1 = x1 - half_g
            iy1 = y1 - half_g
            # Wrap-draw horizontally
            for ox in (-size, 0, size):
                wx0, wx1 = ix0 + ox, ix1 + ox
                if wx1 <= 0 or wx0 >= size:
                    continue
                cx0 = max(0, wx0)
                cx1 = min(size, wx1)
                cy0 = max(0, iy0)
                cy1 = min(size, iy1)
                if cx1 <= cx0 or cy1 <= cy0:
                    continue
                variation = random.randint(-8, 8)
                color = _shift_color(main_color, variation)
                draw.rectangle([cx0, cy0, cx1 - 1, cy1 - 1], fill=color)

    # Soften vertical seams that sit on texture edge (already wrapped)
    img = _apply_stains(img, stain_color, num_blobs, strength=0.45)
    return img


def generate_texture(
    pattern: str,
    size: int = 1024,
    tiles_per_texture: int = 4,
    grout_thickness: int = 6,
    main_color: tuple[int, int, int] = DEFAULT_MAIN,
    grout_color: tuple[int, int, int] = DEFAULT_GROUT,
    stain_color: tuple[int, int, int] = DEFAULT_STAIN,
    seed: int = 7,
    num_blobs: int | None = None,
) -> Image.Image:
    random.seed(seed)
    np.random.seed(seed)
    blobs = num_blobs if num_blobs is not None else (26 if pattern == "floor" else 22)
    if pattern == "floor":
        return generate_floor(
            size, tiles_per_texture, grout_thickness, main_color, grout_color, stain_color, blobs
        )
    if pattern == "wall_brick":
        return generate_wall_brick(
            size, tiles_per_texture, grout_thickness, main_color, grout_color, stain_color, blobs
        )
    raise ValueError(f"Unknown pattern: {pattern!r} (use floor | wall_brick)")


def _uid_for(path: Path) -> str:
    digest = hashlib.md5(str(path.as_posix()).encode("utf-8")).hexdigest()[:13]
    return f"uid://g{digest}"


def write_godot_import(png_path: Path, res_path: str | None = None) -> Path:
    """Write a Godot 4 .import sidecar: mipmaps on, 3D-friendly, repeat via shader hint."""
    png_path = png_path.resolve()
    try:
        rel = png_path.relative_to(ROOT).as_posix()
    except ValueError:
        rel = png_path.name
    source = res_path or f"res://{rel}"
    # Stable imported ctex name (Godot regenerates hash on reimport; placeholder is fine)
    digest = hashlib.md5(source.encode("utf-8")).hexdigest()
    dest = f"res://.godot/imported/{png_path.name}-{digest}.ctex"
    uid = _uid_for(png_path)

    content = f"""[remap]

importer="texture"
type="CompressedTexture2D"
uid="{uid}"
path="{dest}"
metadata={{
"vram_texture": false
}}

[deps]

source_file="{source}"
dest_files=["{dest}"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""
    import_path = Path(str(png_path) + ".import")
    import_path.write_text(content, encoding="utf-8")
    return import_path


def save_texture(img: Image.Image, output: Path, write_import: bool = True) -> Path:
    output = output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    img.save(output)
    if write_import:
        write_godot_import(output)
    return output


def run_batch(
    out_dir: Path | None = None,
    size: int = 1024,
    tiles_per_texture: int = 4,
    grout_thickness: int = 6,
    palettes: Sequence[dict] | None = None,
    extra_seeds: Iterable[int] | None = None,
) -> list[Path]:
    """Generate multiple palette (+ optional seed) variants under textures/generated/."""
    out_dir = out_dir or DEFAULT_OUT_DIR
    out_dir.mkdir(parents=True, exist_ok=True)
    palettes = list(palettes or BATCH_PALETTES)
    seeds_extra = list(extra_seeds or [])
    written: list[Path] = []

    for pal in palettes:
        name = str(pal["name"])
        pattern = str(pal["pattern"])
        main = tuple(pal["main"])  # type: ignore[arg-type]
        grout = tuple(pal["grout"])  # type: ignore[arg-type]
        stain = tuple(pal["stain"])  # type: ignore[arg-type]
        seed = int(pal.get("seed", 7))
        seed_list = [seed] + [seed + s for s in seeds_extra]
        for s in seed_list:
            suffix = "" if s == seed else f"_s{s}"
            out = out_dir / f"{name}{suffix}.png"
            img = generate_texture(
                pattern=pattern,
                size=size,
                tiles_per_texture=tiles_per_texture,
                grout_thickness=grout_thickness,
                main_color=main,  # type: ignore[arg-type]
                grout_color=grout,  # type: ignore[arg-type]
                stain_color=stain,  # type: ignore[arg-type]
                seed=s,
            )
            save_texture(img, out)
            written.append(out)
            print(f"Wrote {out.relative_to(ROOT)}")
    return written


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Generate toon tile albedo PNGs for Godot.")
    p.add_argument(
        "--pattern",
        choices=("floor", "wall_brick"),
        default="floor",
        help="Tile layout (floor grid or offset brick wall)",
    )
    p.add_argument("--main-color", type=parse_rgb, default=DEFAULT_MAIN, help="R,G,B")
    p.add_argument("--grout-color", type=parse_rgb, default=DEFAULT_GROUT, help="R,G,B")
    p.add_argument("--stain-color", type=parse_rgb, default=DEFAULT_STAIN, help="R,G,B")
    p.add_argument("--tiles-per-texture", type=int, default=4)
    p.add_argument("--size", type=int, default=1024)
    p.add_argument("--grout-thickness", type=int, default=6)
    p.add_argument("--seed", type=int, default=7)
    p.add_argument("--num-blobs", type=int, default=None)
    p.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Output PNG path (default: textures/generated/<pattern>_tile.png)",
    )
    p.add_argument(
        "--batch",
        action="store_true",
        help="Generate built-in campaign palettes into textures/generated/",
    )
    p.add_argument(
        "--batch-extra-seeds",
        type=int,
        nargs="*",
        default=[],
        help="Extra seed offsets added to each batch palette (e.g. 100 200)",
    )
    p.add_argument("--no-import", action="store_true", help="Skip writing .import sidecars")
    return p


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.batch:
        run_batch(
            size=args.size,
            tiles_per_texture=args.tiles_per_texture,
            grout_thickness=args.grout_thickness,
            extra_seeds=args.batch_extra_seeds,
        )
        return 0

    out = args.output
    if out is None:
        out = DEFAULT_OUT_DIR / f"{args.pattern}_tile.png"
    elif not out.is_absolute():
        out = (ROOT / out).resolve()

    img = generate_texture(
        pattern=args.pattern,
        size=args.size,
        tiles_per_texture=args.tiles_per_texture,
        grout_thickness=args.grout_thickness,
        main_color=args.main_color,
        grout_color=args.grout_color,
        stain_color=args.stain_color,
        seed=args.seed,
        num_blobs=args.num_blobs,
    )
    save_texture(img, out, write_import=not args.no_import)
    print(f"Wrote {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
