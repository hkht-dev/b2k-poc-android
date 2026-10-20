"""Nanda's door in the tower block's south face (tools/interiors/nanda_flat.py).

GDD §5: "Nanda's flat at the end of the alley". The door is in the tower's
face at (-29, 0, -18.5), where Old Nanda stands beside it
(competitors.py NANDA_POS): a frame, a leaf with a barred peephole in it
(GDD §5: locks and grilles in every household), his sign over it, and the
spawn point just outside, facing south, that the flat's door back names
("nanda_door"). It used to stand free in the alley four metres south while
competitors.py drew a second, look-only door here; one door now.
"""

from __future__ import annotations

import math

from scenegen import Builder

PLACE, SPAWN = "nanda_flat", "nanda_door"
# competitors.py TOWER_FACE_Z: the block's south face.
FACE = -18.5
X, Z = -29.0, FACE + 0.1
G = "NandaDoor"
SOUTH = math.pi


def build(b: Builder) -> None:
    b.group(G)
    b.detail("Leaf", G, (X, 1.1, Z - 0.15), (1.1, 2.2, 0.1), "timber")
    for side, dx in (("L", -0.65), ("R", 0.65)):
        b.detail(f"Frame{side}", G, (X + dx, 1.15, Z - 0.1), (0.14, 2.3, 0.2), "timber")
    b.detail("Lintel", G, (X, 2.36, Z - 0.1), (1.5, 0.14, 0.2), "timber")
    b.solid("Step", G, (X, 0.05, Z + 0.3), (1.6, 0.1, 0.6), "ph_concrete")
    # A small barred window in the leaf, dark behind the bars.
    b.detail("Peephole", G, (X, 1.6, Z - 0.09), (0.36, 0.26, 0.02), "tyre")
    b.multimesh("PeepholeBars", G, "BoxMesh_unit", "rust_metal",
                [((X + dx, 1.6, Z - 0.075), 0.0, (0.02, 0.3, 0.02)) for dx in (-0.1, 0.0, 0.1)], shadows=False)
    b.label("NandaSign", G, "sign.nanda", (X, 2.6, Z + 0.02), 0.0, size=40)
    b.door("Door", G, PLACE, SPAWN, "verb.enter", (X, 0, Z + 0.8), size=(2.4, 2.2, 1.8))
    b.spawn("Spawn", G, SPAWN, (X, 0.05, Z + 1.5), SOUTH)
