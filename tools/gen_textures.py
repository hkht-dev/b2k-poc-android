#!/usr/bin/env python3
"""Generate the street's tileable textures procedurally and write them as PNGs.

docs/BRIEF_AMENDMENT_1.md §B: textures are required on every surface, with a
stylized, hand-painted look; procedural generation is the preferred source for
tiling surfaces. Every surface here is made by this script in the Hollow Vale
palette of GDD §10 (ochre, dust, timber brown, flat overcast white, rust red),
tileable in both axes, and replaceable 1:1 by painted textures later.

`stylise()` is also the albedo-only pass that tools/fetch_polyhaven.py applies
to CC0 photographic textures so they sit in the same painted register.

    python3 tools/gen_textures.py            # writes assets/textures/*.png
    python3 tools/gen_textures.py --check    # fails if any PNG is stale

Requires numpy and Pillow.
"""

from __future__ import annotations

import argparse
import io
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "textures"
SIZE = 1024  # docs/BRIEF_AMENDMENT_1.md §B1: 1024 or 2048
SEED = 108  # fixed, so the output is reproducible and --check is meaningful


def rng(name: str) -> np.random.Generator:
    return np.random.default_rng(SEED + sum(map(ord, name)))


def periodic_blur(a: np.ndarray, radius: int) -> np.ndarray:
    """Box blur that wraps at the edges, so the result still tiles."""
    out = np.zeros_like(a)
    n = 0
    for dy in range(-radius, radius + 1):
        for dx in range(-radius, radius + 1):
            out += np.roll(np.roll(a, dy, axis=0), dx, axis=1)
            n += 1
    return out / n


def noise(name: str, octaves=((64, 1.0), (16, 0.5), (4, 0.25), (1, 0.12))) -> np.ndarray:
    """Tileable multi-octave value noise in [0, 1]."""
    g = rng(name)
    total = np.zeros((SIZE, SIZE))
    weight = 0.0
    for radius, amp in octaves:
        layer = g.random((SIZE, SIZE))
        if radius > 1:
            layer = periodic_blur(layer, radius // 4)
            layer = periodic_blur(layer, radius // 4)
        layer = (layer - layer.min()) / max(layer.max() - layer.min(), 1e-6)
        total += layer * amp
        weight += amp
    return total / weight


def to_rgb(base: tuple, lum: np.ndarray, tint: np.ndarray | None = None) -> np.ndarray:
    """A base colour shaded by a luminance field, optional per-pixel tint."""
    img = np.ones((SIZE, SIZE, 3)) * np.array(base) / 255.0
    img *= lum[..., None]
    if tint is not None:
        img *= tint
    return np.clip(img, 0, 1)


def stylise(img: np.ndarray, strength: float = 1.0) -> np.ndarray:
    """The painted look, applied to any albedo (ours or a CC0 photo).

    Softens fine photographic detail, flattens the luminance into a few broad
    bands so surfaces read as brushwork rather than grain, nudges saturation
    up, and lays a faint grime mask into the low bands. Albedo only: normals,
    roughness and height are never touched, because the game ships none.
    """
    h, w = img.shape[:2]
    # 1. soften: a periodic blur so tiling survives
    soft = np.stack([periodic_blur(img[..., c], 2) for c in range(3)], axis=-1)
    img = img * (1 - 0.55 * strength) + soft * (0.55 * strength)
    # 2. luminance bands
    lum = img.mean(axis=-1, keepdims=True)
    bands = 7
    banded = np.floor(lum * bands + 0.5) / bands
    lum_mix = lum * (1 - 0.6 * strength) + banded * (0.6 * strength)
    img = img * (lum_mix / np.maximum(lum, 1e-4))
    # 3. saturation
    mean = img.mean(axis=-1, keepdims=True)
    img = mean + (img - mean) * (1 + 0.18 * strength)
    # 4. grime in the low frequencies
    g = np.random.default_rng(SEED).random((h, w))
    grime = periodic_blur(periodic_blur(g, 12), 12)
    grime = (grime - grime.min()) / max(grime.max() - grime.min(), 1e-6)
    img = img * (1 - 0.12 * strength * grime)[..., None]
    return np.clip(img, 0, 1)


def save(name: str, img: np.ndarray) -> bytes:
    data = (img * 255).astype(np.uint8)
    buf = io.BytesIO()
    Image.fromarray(data, "RGB").save(buf, format="PNG", optimize=True)
    return buf.getvalue()


# -- surfaces -----------------------------------------------------------------


def plaster(name: str, base: tuple) -> np.ndarray:
    n = noise(name)
    grain = noise(name + "g", ((2, 1.0), (1, 0.6)))
    streak = noise(name + "s", ((64, 1.0),))
    # Periodic in y, so the weathering band does not leave a seam where the
    # texture tiles.
    y = 0.5 - 0.5 * np.cos(np.linspace(0, 2 * np.pi, SIZE, endpoint=False))[:, None]
    lum = 0.86 + 0.16 * n + 0.08 * (grain - 0.5) - 0.06 * streak * y
    return to_rgb(base, lum)


def brick(name: str, base=(168, 92, 62), mortar=(205, 195, 178)) -> np.ndarray:
    g = rng(name)
    bh, bw, gap = 32, 96, 5  # 16 rows, tiles because 512 % 32 == 0, 512 % 96 != 0 -> use 128
    bw = 128
    img = np.ones((SIZE, SIZE, 3)) * np.array(mortar) / 255.0
    rows = SIZE // bh
    for r in range(rows):
        offset = (bw // 2) if r % 2 else 0
        for c in range(-1, SIZE // bw + 1):
            x0 = c * bw + offset
            y0 = r * bh
            jitter = 0.82 + 0.3 * g.random()
            colour = np.array(base) / 255.0 * jitter
            y1, x1 = y0 + bh - gap, x0 + bw - gap
            ys = slice(max(y0, 0), min(y1, SIZE))
            xs = slice(max(x0, 0), min(x1, SIZE))
            if xs.start < xs.stop and ys.start < ys.stop:
                img[ys, xs] = colour
            # wrap the brick that runs off the right edge onto the left
            if x1 > SIZE:
                img[ys, 0 : x1 - SIZE] = colour
    n = noise(name + "n", ((8, 1.0), (2, 0.6)))
    return np.clip(img * (0.86 + 0.26 * n)[..., None], 0, 1)


def concrete(name: str, base: tuple) -> np.ndarray:
    n = noise(name)
    speck = (rng(name + "sp").random((SIZE, SIZE)) > 0.985).astype(float)
    lum = 0.84 + 0.18 * n - 0.25 * speck
    img = to_rgb(base, lum)
    # a few hairline cracks
    g = rng(name + "cr")
    for _ in range(4):
        x, y = g.integers(0, SIZE), g.integers(0, SIZE)
        for _ in range(220):
            img[y % SIZE, x % SIZE] *= 0.72
            x += int(g.integers(-1, 2))
            y += int(g.integers(0, 2))
    return np.clip(img, 0, 1)


def asphalt(name: str) -> np.ndarray:
    n = noise(name, ((8, 1.0), (2, 0.7), (1, 0.5)))
    lum = 0.7 + 0.5 * n
    return to_rgb((92, 90, 86), lum)


def timber(name: str, base=(126, 92, 60)) -> np.ndarray:
    x = np.arange(SIZE)[None, :]
    plank = 64
    seam = ((x % plank) < 3).astype(float)
    grain = noise(name, ((1, 1.0), (4, 0.4)))
    yy = np.linspace(0, 8 * np.pi, SIZE)[:, None]
    waves = 0.5 + 0.5 * np.sin(yy + 2.5 * grain)
    lum = 0.78 + 0.3 * grain * 0.5 + 0.14 * waves - 0.45 * seam
    g = rng(name + "p")
    tint = np.ones((SIZE, SIZE, 3))
    for p in range(SIZE // plank):
        tint[:, p * plank : (p + 1) * plank] *= 0.9 + 0.2 * g.random()
    return to_rgb(base, lum, tint)


def corrugated(name: str, base=(176, 174, 166)) -> np.ndarray:
    x = np.arange(SIZE)[None, :]
    ridge = 0.5 + 0.5 * np.sin(x / 512 * 2 * np.pi * 24)
    n = noise(name, ((16, 1.0), (2, 0.4)))
    rust = noise(name + "r", ((32, 1.0),))
    lum = 0.7 + 0.35 * ridge + 0.1 * n
    tint = np.ones((SIZE, SIZE, 3))
    rust_mask = np.clip((rust - 0.62) * 4, 0, 1)
    tint[..., 1] -= 0.45 * rust_mask
    tint[..., 2] -= 0.6 * rust_mask
    return to_rgb(base, lum, tint)


def rust_metal(name: str, base=(158, 59, 43)) -> np.ndarray:
    n = noise(name, ((32, 1.0), (8, 0.6), (2, 0.4)))
    flake = noise(name + "f", ((4, 1.0),))
    lum = 0.72 + 0.4 * n - 0.2 * (flake > 0.7)
    return to_rgb(base, lum)


def cloth(name: str, base: tuple) -> np.ndarray:
    x = np.arange(SIZE)[None, :]
    y = np.arange(SIZE)[:, None]
    weave = 0.5 + 0.25 * np.sin(x * np.pi / 2) + 0.25 * np.sin(y * np.pi / 2)
    n = noise(name, ((16, 1.0), (2, 0.3)))
    lum = 0.86 + 0.1 * weave + 0.12 * n
    return to_rgb(base, lum)


def skin(name: str, base=(176, 124, 92)) -> np.ndarray:
    n = noise(name, ((32, 1.0), (4, 0.3)))
    return to_rgb(base, 0.92 + 0.12 * n)


def sign_glyphs(name: str) -> np.ndarray:
    """A shop sign in an invented script: timber strokes on cream.

    §B3 asks for signs "in an invented script" — readable as writing, not as
    any language. Glyphs are clusters of short strokes on a baseline, so the
    board reads as lettering from across the street and as nothing up close.
    """
    g = rng(name)
    h, w = 256, 1024
    img = np.ones((h, w, 3)) * np.array((226, 206, 160)) / 255.0
    ink = np.array((78, 54, 34)) / 255.0
    x = 40
    while x < w - 60:
        glyph_w = int(g.integers(28, 52))
        strokes = int(g.integers(2, 5))
        for _ in range(strokes):
            kind = g.integers(0, 3)
            if kind == 0:  # vertical
                sx = x + int(g.integers(0, glyph_w - 6))
                y0, y1 = int(g.integers(70, 110)), int(g.integers(150, 200))
                img[y0:y1, sx : sx + 7] = ink
            elif kind == 1:  # horizontal
                sy = int(g.integers(80, 190))
                img[sy : sy + 7, x : x + glyph_w] = ink
            else:  # diagonal
                for t in range(glyph_w):
                    yy = int(90 + (t / glyph_w) * 90)
                    img[yy : yy + 7, x + t : x + t + 6] = ink
        # a headline bar over most glyphs, as in several Indic scripts
        if g.random() < 0.8:
            img[72:79, x - 2 : x + glyph_w + 2] = ink
        x += glyph_w + int(g.integers(14, 34))
    noise_small = np.random.default_rng(SEED + 7).random((h, w))
    img *= (0.92 + 0.08 * noise_small)[..., None]
    return np.clip(img, 0, 1)


TEXTURES = {
    "sign_glyphs": lambda: sign_glyphs("sign"),
    "plaster_ochre": lambda: plaster("ochre", (214, 160, 72)),
    "plaster_white": lambda: plaster("white", (232, 226, 214)),
    "plaster_cream": lambda: plaster("cream", (226, 206, 160)),
    "brick": lambda: brick("brick"),
    "concrete_dust": lambda: concrete("dust", (198, 186, 160)),
    "asphalt": lambda: asphalt("asphalt"),
    "timber": lambda: timber("timber"),
    "corrugated": lambda: corrugated("corr"),
    "rust_metal": lambda: rust_metal("rust"),
    "coat": lambda: cloth("coat", (86, 94, 90)),
    "cloth_pale": lambda: cloth("pale", (214, 204, 176)),
    "skin": lambda: skin("skin"),
}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="fail if any PNG is stale")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    stale = []
    for name, make in TEXTURES.items():
        path = OUT / f"{name}.png"
        fresh = save(name, stylise(make(), strength=0.5))
        if args.check:
            if not path.exists() or path.read_bytes() != fresh:
                stale.append(name)
        else:
            path.write_bytes(fresh)
            print(f"gen_textures: wrote {path.relative_to(ROOT)} ({len(fresh) // 1024} KB)")
    if args.check:
        if stale:
            print(f"gen_textures: stale: {', '.join(stale)}; run tools/gen_textures.py", file=sys.stderr)
            return 1
        print(f"gen_textures: {len(TEXTURES)} textures current")
    return 0


if __name__ == "__main__":
    sys.exit(main())
