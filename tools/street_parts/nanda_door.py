"""Nanda's door at the end of the west alley (tools/interiors/nanda_flat.py).

GDD §5: "Nanda's flat at the end of the alley". The alley's walls are
another part's; this is only the door at (-29, 0, -13.5), facing south into
the alley: a frame, a leaf with a barred peephole in it (GDD §5: locks and
grilles in every household), and the spawn point just outside, facing south,
that the flat's door back names ("nanda_door").
"""

from __future__ import annotations

import math

from scenegen import Builder

PLACE, SPAWN = "nanda_flat", "nanda_door"
X, Z = -29.0, -13.5
G = "NandaDoor"
SOUTH = math.pi


def build(b: Builder) -> None:
    b.group(G)
    b.solid("Leaf", G, (X, 1.1, Z - 0.15), (1.1, 2.2, 0.1), "timber", collide=False)
    for side, dx in (("L", -0.65), ("R", 0.65)):
        b.solid(f"Frame{side}", G, (X + dx, 1.15, Z - 0.1), (0.14, 2.3, 0.2), "timber", collide=False)
    b.solid("Lintel", G, (X, 2.36, Z - 0.1), (1.5, 0.14, 0.2), "timber", collide=False)
    b.solid("Step", G, (X, 0.05, Z + 0.3), (1.6, 0.1, 0.6), "ph_concrete")
    # A small barred window in the leaf, dark behind the bars.
    b.solid("Peephole", G, (X, 1.6, Z - 0.09), (0.36, 0.26, 0.02), "tyre", collide=False)
    b.multimesh("PeepholeBars", G, "BoxMesh_unit", "rust_metal",
                [((X + dx, 1.6, Z - 0.075), 0.0, (0.02, 0.3, 0.02)) for dx in (-0.1, 0.0, 0.1)], shadows=False)
    b.door("Door", G, PLACE, SPAWN, "verb.enter", (X, 0, Z), size=(2.4, 2.2, 1.8))
    b.spawn("Spawn", G, SPAWN, (X, 0.05, Z + 1.1), SOUTH)
