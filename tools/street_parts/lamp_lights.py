"""Sodium-orange lamp lights on the lamp posts nearest the fountain.

GDD §5, Hollow Vale row: "sodium-orange street lamps ... Act 4: dusk,
lamplit". One OmniLight3D per post, no shadow, hidden until a stage in
data/daylight.json says `lamps_on`; scripts/street/daylight.gd switches the
group `street_lamp` and fades them in. Six lights, off by default, is the
mobile budget (docs/BRIEF_AMENDMENT_1.md §C: one real-time directional
light; omni lights only where the story needs them).

The posts themselves are placed by tools/gen_street.py, which hands their
(x, z) positions over as `b.lamp_posts` before the parts run.

PLACEHOLDER: a bare point light; the painted lamp head of GDD §10 adds an
emissive glass when the posts are modelled.
"""

from __future__ import annotations

import math

from scenegen import xf

LAMP_COUNT = 6
# The head of Poly Haven's street_lamp_01 at the generator's scale (1.35 x 3.9 m).
LIGHT_HEIGHT = 4.9
# Sodium vapour: orange, not amber and not the Glimpse's warm backlight.
COLOUR = (1.0, 0.62, 0.22)
ENERGY = 1.5
RANGE = 9.0


def nearest_posts(posts) -> list:
    """The LAMP_COUNT posts nearest the fountain (the origin), west to east."""
    chosen = sorted(posts, key=lambda p: math.hypot(p[0], p[1]))[:LAMP_COUNT]
    return sorted(chosen)


def build(b) -> None:
    posts = getattr(b, "lamp_posts", None)
    if posts is None:
        raise RuntimeError("lamp_lights: gen_street.py must set b.lamp_posts before the parts run")
    b.group("LampLights", "Lamps")
    r, g, bl = COLOUR
    for i, (x, z) in enumerate(nearest_posts(posts)):
        b.nodes.append(
            f'[node name="LampLight{i}" type="OmniLight3D" parent="Lamps/LampLights" groups=["street_lamp"]]\n'
            f"transform = {xf((x, LIGHT_HEIGHT, z))}\n"
            "visible = false\n"
            f"light_color = Color({r:g}, {g:g}, {bl:g}, 1)\n"
            f"light_energy = {ENERGY:g}\n"
            f"omni_range = {RANGE:g}\n"
            "shadow_enabled = false\n\n"
        )
