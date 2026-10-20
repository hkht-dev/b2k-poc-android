"""The Counting Man at the bus stop (GDD §7): a man on the far end of the
bench who cannot stop counting coins, and the coins on the seat beside him.

The man is scenes/npc/CountingMan.tscn (scripts/npc/counting_man.gd) in the
criminalMaleA skin; the route he walks when freed is data on the node here.
The coins are one MultiMesh of flat cylinders: a few short stacks and the
loose ones he is counting, hidden by his script once he has picked them up
and gone. The bench (gen_street.py BENCHES[0]) is 4.4 m long, centred near
x 9.4, facing north; he sits at its east end with the stop sign at his back.

PLACEHOLDER: the body is the shared Kenney rig and the coins are
primitives; replaced by the painted characters and props of GDD §10.
"""

from __future__ import annotations

import math

from scenegen import xf

EXT = (
    '[ext_resource type="PackedScene" path="res://scenes/npc/CountingMan.tscn" '
    'id="16_counting_man"]\n'
)

# Where he sits: the pavement under the bench's east end (y 0.16 is the kerb).
SEAT = (11.4, 0.16, 20.9)
# Off the bench past the shelter post, east along the pavement (clear of the
# litter can at x 18 and the lamp at x 21), round the corner and south down
# the kerb of the north-south road until he is out of sight.
WALK = [(13.2, 0.16, 23.3), (20.0, 0.16, 23.3), (22.6, 0.16, 25.4), (22.8, 0.16, 45.0)]
# The seat top, as near as a headless build can place it: kerb plus 0.45 m.
SEAT_TOP = 0.16 + 0.45
COIN_RADIUS = 0.03
COIN_THICK = 0.008


def _coins() -> list:
    """Stacks and loose coins on the seat west of him: (pos, yaw, scale)."""
    size = (COIN_RADIUS * 2, COIN_THICK, COIN_RADIUS * 2)
    out = []
    for i, (x, z, height) in enumerate(
        ((10.0, 20.8, 5), (10.26, 21.0, 4), (10.5, 20.78, 3), (10.76, 20.98, 6))
    ):
        for level in range(height):
            yaw = (i * 1.7 + level * 0.9) % math.pi
            out.append(((x, SEAT_TOP + COIN_THICK * (level + 0.5), z), yaw, size))
    for i in range(14):
        col, row = i % 7, i // 7
        x = 9.86 + col * 0.17 + 0.03 * math.sin(i * 2.3)
        z = 20.72 + row * 0.3 + 0.04 * math.cos(i * 1.9)
        out.append(((x, SEAT_TOP + COIN_THICK * 0.5, z), (i * 0.8) % math.pi, size))
    return out


def build(b) -> None:
    b.multimesh("Coins", "BusStop", "CylinderMesh_unit", "plaster_ochre", _coins(), shadows=False)
    points = ", ".join(f"{c:g}" for p in WALK for c in p)
    b.nodes.append(
        '[node name="CountingMan" parent="BusStop" instance=ExtResource("16_counting_man")]\n'
        "unique_name_in_owner = true\n"
        f"transform = {xf(SEAT)}\n"
        f"walk_points = PackedVector3Array({points})\n"
        'coins_path = NodePath("../Coins")\n\n'
    )
