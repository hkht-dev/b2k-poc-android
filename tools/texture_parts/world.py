"""The growing world's surfaces: the Grove's meadow and river bed, the
interiors' floors, boards and cloths, the temple's stone, the kadamba's bark.

GDD §5 names what they dress: the Grove riverbank (grass, the river, the
kadamba tree with its swing) and Hollow Vale's enterable interiors and shrine
room. GDD §10 sets the colour: the Grove's rose-gold dusk warms its greens
and browns; Hollow Vale keeps ochre, dust and timber; peacock blue and
magenta appear in none of these (they are reserved for the Song's return and
for Glimpses). Every surface tiles in both axes at SIZE square, built only
from periodic noise and grids that divide SIZE, and each is a PLACEHOLDER for
the hand-painted texture of GDD §10 "painted stylized 3D".

Found and run by tools/gen_textures.py (see tools/texture_parts/README.md).
"""

from __future__ import annotations

import numpy as np

from gen_textures import SIZE, cloth, noise, periodic_blur, rng, to_rgb


def _normalise(a: np.ndarray) -> np.ndarray:
    return (a - a.min()) / max(a.max() - a.min(), 1e-6)


def _streak(a: np.ndarray, rx: int, ry: int) -> np.ndarray:
    """A wrapping box blur with separate radii, so the result is drawn out
    along one axis: grass blades, wood grain, bark ridges, chalk wipes."""
    out = np.zeros_like(a)
    n = 0
    for dy in range(-ry, ry + 1):
        for dx in range(-rx, rx + 1):
            out += np.roll(np.roll(a, dy, axis=0), dx, axis=1)
            n += 1
    return _normalise(out / n)


def _wrap(y0: int, x0: int, h: int, w: int) -> tuple:
    """Index arrays for an h x w patch at (y0, x0) that wraps round the tile."""
    return np.ix_(np.arange(y0, y0 + h) % SIZE, np.arange(x0, x0 + w) % SIZE)


# -- the Grove ------------------------------------------------------------------


def grass(name: str, base=(116, 142, 70)) -> np.ndarray:
    """A soft meadow seen from above. Clumps from broad noise, blades from a
    fine grain drawn out a little, and the amber of the low sun (GDD §5
    "eternal rose-gold dusk") on the tips. PLACEHOLDER: in the game grass is
    also GPU-instanced billboards (GDD §5); this is the ground under them."""
    clumps = noise(name, ((48, 1.0), (12, 0.6)))
    blades = _streak(rng(name + "b").random((SIZE, SIZE)), 0, 3)
    lum = 0.74 + 0.3 * clumps + 0.24 * (blades - 0.5)
    warm = np.clip((clumps - 0.45) * 2.2, 0, 1)
    tint = np.ones((SIZE, SIZE, 3))
    tint[..., 0] += 0.2 * warm
    tint[..., 2] -= 0.14 * warm
    return to_rgb(base, lum, tint)


def river_bed(name: str, base=(104, 96, 88)) -> np.ndarray:
    """Dark wet pebbles over sand: domes laid down largest first, lit from
    the top left, every one wrapping round the tile's edges."""
    g = rng(name)
    height = np.zeros((SIZE, SIZE))
    shade = np.zeros((SIZE, SIZE))
    for i in range(1100):
        big = i < 260
        rx = g.uniform(22, 44) if big else g.uniform(9, 22)
        ry = rx * g.uniform(0.6, 0.95)
        cy, cx = g.random() * SIZE, g.random() * SIZE
        ang = g.uniform(0, np.pi)
        r = int(max(rx, ry)) + 2
        y0, x0 = int(cy) - r, int(cx) - r
        yy, xx = np.meshgrid(
            np.arange(y0, y0 + 2 * r + 1) - cy, np.arange(x0, x0 + 2 * r + 1) - cx, indexing="ij"
        )
        c, s = np.cos(ang), np.sin(ang)
        u = (xx * c + yy * s) / rx
        v = (-xx * s + yy * c) / ry
        dome = np.sqrt(np.clip(1 - (u * u + v * v), 0, 1))
        idx = _wrap(y0, x0, 2 * r + 1, 2 * r + 1)
        over = dome > height[idx]
        height[idx] = np.where(over, dome, height[idx])
        shade[idx] = np.where(over, g.uniform(0.5, 1.0), shade[idx])
    gy = np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)
    gx = np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)
    light = np.clip(0.55 - 1.6 * (gx + gy), 0.2, 1.1)
    sand = noise(name + "s", ((8, 1.0), (2, 0.5)))
    pebble = height > 0.02
    lum = np.where(pebble, (0.5 + 0.55 * shade) * light, 0.42 + 0.22 * sand)
    tint = np.ones((SIZE, SIZE, 3))
    # some pebbles brown, some grey-green, the sand a touch warmer
    hue = _streak(rng(name + "h").random((SIZE, SIZE)), 6, 6)
    tint[..., 0] += 0.1 * (hue - 0.5) + 0.06 * (~pebble)
    tint[..., 2] -= 0.12 * (hue - 0.5)
    return to_rgb(base, lum, tint)


def bark_kadamba(name: str, base=(130, 92, 62)) -> np.ndarray:
    """Bark drawn out into vertical ridges with dark fissures between, in the
    warm brown the dusk gives the kadamba (GDD §5, §10 Grove row).
    PLACEHOLDER for the custom kadamba tree of GDD §10 "Asset sourcing"."""
    ridges = _streak(rng(name).random((SIZE, SIZE)), 1, 28)
    fine = noise(name + "f", ((2, 1.0), (1, 0.6)))
    bands = noise(name + "b", ((64, 1.0),))
    fissure = np.clip((0.42 - ridges) * 6, 0, 1)
    lum = 0.66 + 0.5 * ridges + 0.12 * (fine - 0.5) + 0.16 * (bands - 0.5) - 0.42 * fissure
    tint = np.ones((SIZE, SIZE, 3))
    tint[..., 0] += 0.12 * ridges
    tint[..., 2] -= 0.1 * ridges
    return to_rgb(base, lum, tint)


# -- interiors ------------------------------------------------------------------


def tile_floor(name: str, base=(176, 96, 62), grout=(168, 154, 134)) -> np.ndarray:
    """Terracotta tiles, eight by eight to the tile, with pale grout lines and
    a worn centre on each. SIZE divides by the cell, so the grid wraps."""
    cell, gap = 128, 6
    g = rng(name)
    img = np.ones((SIZE, SIZE, 3)) * np.array(grout) / 255.0
    for r in range(SIZE // cell):
        for c in range(SIZE // cell):
            y0, x0 = r * cell + gap // 2, c * cell + gap // 2
            jitter = np.array([0.86 + 0.28 * g.random(), 0.9 + 0.2 * g.random(), 1.0])
            img[y0 : y0 + cell - gap, x0 : x0 + cell - gap] = np.array(base) / 255.0 * jitter
    yy = ((np.arange(SIZE) % cell) / cell)[:, None]
    xx = ((np.arange(SIZE) % cell) / cell)[None, :]
    worn = 1 - 0.5 * (np.abs(yy - 0.5) + np.abs(xx - 0.5))
    n = noise(name + "n", ((16, 1.0), (4, 0.5), (1, 0.3)))
    lum = 0.78 + 0.2 * n + 0.1 * worn
    return np.clip(img * lum[..., None], 0, 1)


def parquet(name: str, base=(152, 108, 66)) -> np.ndarray:
    """Wood strips laid in staggered rows, grain running along each, a dark
    seam at every end and between rows."""
    strip_w, strip_l = 64, 256
    g = rng(name)
    grain = _streak(rng(name + "g").random((SIZE, SIZE)), 24, 0)
    fine = noise(name + "f", ((1, 1.0), (4, 0.4)))
    tint = np.ones((SIZE, SIZE, 3))
    seam = np.zeros((SIZE, SIZE))
    for r in range(SIZE // strip_w):
        offset = (r % 4) * (strip_l // 4)
        y0 = r * strip_w
        for c in range(SIZE // strip_l):
            x0 = c * strip_l + offset
            idx = _wrap(y0, x0, strip_w, strip_l)
            shade = 0.86 + 0.28 * g.random()
            tint[idx] = tint[idx] * np.array([shade, shade * (0.9 + 0.08 * g.random()), 1.0])
            seam[_wrap(y0, x0, strip_w, 3)] = 1.0
        seam[y0 : y0 + 2, :] = 1.0
    lum = 0.8 + 0.3 * (grain - 0.5) + 0.1 * (fine - 0.5) - 0.4 * seam
    return to_rgb(base, lum, tint)


def fabric_print(name: str, base=(214, 164, 86), ink=(156, 50, 40)) -> np.ndarray:
    """A small block print on ochre cloth: a diamond ring with a dot inside,
    a dot on the half lattice between, the ink bleeding and missing a little
    as a wooden block does. Shop cloths and cushions."""
    img = cloth(name, base)
    cell = 64
    yy, xx = np.meshgrid(np.arange(SIZE) % cell, np.arange(SIZE) % cell, indexing="ij")
    cy, cx = yy - cell / 2 + 0.5, xx - cell / 2 + 0.5
    diamond = np.abs(cx) + np.abs(cy)
    ring = (diamond > 14) & (diamond < 19)
    dot = cx * cx + cy * cy < 4.5**2
    cy2 = (yy + cell // 2) % cell - cell / 2 + 0.5
    cx2 = (xx + cell // 2) % cell - cell / 2 + 0.5
    corner = cx2 * cx2 + cy2 * cy2 < 3.5**2
    mask = periodic_blur((ring | dot | corner).astype(float), 1)
    mask = np.clip(mask * (0.7 + 0.6 * noise(name + "ink", ((4, 1.0),))), 0, 1)
    ink_rgb = np.array(ink) / 255.0 * (0.8 + 0.3 * img.mean(axis=-1, keepdims=True))
    return np.clip(img * (1 - mask[..., None]) + ink_rgb * mask[..., None], 0, 1)


def chalkboard(name: str, base=(38, 40, 38)) -> np.ndarray:
    """Near-black with faint horizontal wipes of old chalk and a little dust."""
    n = noise(name, ((32, 1.0), (4, 0.4)))
    smudge = np.clip((_streak(rng(name + "s").random((SIZE, SIZE)), 40, 3) - 0.55) * 3, 0, 1)
    dust = (rng(name + "d").random((SIZE, SIZE)) > 0.995).astype(float)
    lum = 0.85 + 0.3 * n + 0.6 * smudge + 0.7 * dust
    return to_rgb(base, lum)


def paper(name: str, base=(236, 224, 194)) -> np.ndarray:
    """Cream paper for scrolls and notices: fibre grain, a slow mottle, and
    a little foxing in the mottle's lows."""
    fibre = noise(name, ((2, 1.0), (1, 0.5)))
    mottle = noise(name + "m", ((48, 1.0), (12, 0.5)))
    lum = 0.9 + 0.08 * mottle + 0.06 * (fibre - 0.5)
    tint = np.ones((SIZE, SIZE, 3))
    fox = np.clip((0.4 - mottle) * 3, 0, 1)
    tint[..., 2] -= 0.08 * fox
    return to_rgb(base, lum, tint)


def stone_old(name: str, base=(150, 138, 118), joint=(78, 70, 60)) -> np.ndarray:
    """Temple ashlar: large warm-grey blocks in offset courses, pitted, with
    an ochre weathering stain where the rain runs. PLACEHOLDER for the
    custom shrine interior of GDD §10 "Asset sourcing"."""
    bh, bw, gap = 128, 256, 5
    g = rng(name)
    img = np.ones((SIZE, SIZE, 3)) * np.array(joint) / 255.0
    for r in range(SIZE // bh):
        offset = bw // 2 if r % 2 else 0
        for c in range(SIZE // bw):
            x0, y0 = c * bw + offset, r * bh
            colour = np.array(base) / 255.0 * (0.84 + 0.28 * g.random())
            colour = colour * np.array([1.0, 1.0, 0.96 + 0.08 * g.random()])
            img[_wrap(y0, x0, bh - gap, bw - gap)] = colour
    pit = noise(name + "p", ((4, 1.0), (1, 0.6)))
    weather = noise(name + "w", ((64, 1.0), (16, 0.5)))
    lum = 0.78 + 0.2 * weather + 0.14 * (pit - 0.5) - 0.2 * (pit > 0.78)
    stain = np.clip((weather - 0.6) * 3, 0, 1)
    tint = np.ones((SIZE, SIZE, 3))
    tint[..., 0] += 0.06 * stain
    tint[..., 2] -= 0.2 * stain
    return np.clip(img * lum[..., None] * tint, 0, 1)


def sari_red(name: str, base=(146, 28, 38), gold=(210, 164, 70)) -> np.ndarray:
    """Deep red cloth with a gold border along the bottom of the tile: a wide
    zari band with a chevron in it and a thin line above. Red, not magenta
    (GDD §10, Hollow Vale row)."""
    img = cloth(name, base)
    thread = cloth(name + "g", gold)
    y = np.arange(SIZE)[:, None]
    x = np.arange(SIZE)[None, :]
    band = ((y >= 860) & (y < 960)) | ((y >= 822) & (y < 836))
    chevron = (((x // 8) + (y // 8)) % 4 == 0) & (y >= 880) & (y < 940)
    thread = thread * (1 - 0.35 * chevron[..., None])
    m = band.astype(float)[..., None]
    return np.clip(img * (1 - m) + thread * m, 0, 1)


TEXTURES = {
    "grass": lambda: grass("w_grass"),
    "river_bed": lambda: river_bed("w_river"),
    "tile_floor": lambda: tile_floor("w_tile"),
    "parquet": lambda: parquet("w_parquet"),
    "fabric_print": lambda: fabric_print("w_print"),
    "chalkboard": lambda: chalkboard("w_chalk"),
    "paper": lambda: paper("w_paper"),
    "stone_old": lambda: stone_old("w_stone"),
    "bark_kadamba": lambda: bark_kadamba("w_bark"),
    "sari_red": lambda: sari_red("w_sari"),
}
