"""The street door into Dhanpal's office (tools/interiors/office.py).

GDD §5: Dhanpal's office is one of the four enterable interiors. The hall
front near (46, 27) is another part's; this is only its door at
(46, 0, 25.9): a frame, leaf and step so it reads as a door before the hall
is there, the brass plaque beside it, and the spawn point just outside,
facing north, that the office's door back names ("office_door").
"""

from __future__ import annotations

import math

from scenegen import Builder

PLACE, SPAWN = "office", "office_door"
X, Z = 46.0, 25.9
G = "OfficeDoor"
# A Label3D's front is its +Z; turned half round it reads from the north.
FACE_NORTH = math.pi


def build(b: Builder) -> None:
    b.group(G)
    b.detail("Leaf", G, (X, 1.15, Z + 0.15), (1.3, 2.3, 0.1), "timber")
    for side, dx in (("L", -0.75), ("R", 0.75)):
        b.detail(f"Frame{side}", G, (X + dx, 1.2, Z + 0.1), (0.14, 2.4, 0.2), "timber")
    b.detail("Lintel", G, (X, 2.46, Z + 0.1), (1.7, 0.14, 0.2), "timber")
    b.solid("Step", G, (X, 0.06, Z - 0.35), (1.9, 0.12, 0.7), "ph_concrete")
    b.detail("PlaquePlate", G, (X + 1.35, 1.6, Z + 0.12), (0.76, 0.24, 0.04), "rust_metal")
    b.label("Plaque", G, "sign.office", (X + 1.35, 1.6, Z + 0.09), FACE_NORTH, size=22, colour=(0.95, 0.82, 0.5, 1))
    # The reach runs from the kerb to the leaf, so *Go in* is offered from
    # the pavement wherever the hall's front wall ends up.
    b.door("Door", G, PLACE, SPAWN, "verb.enter", (X, 0, Z), size=(2.6, 2.2, 2.4))
    b.spawn("Spawn", G, SPAWN, (X, 0.05, Z - 1.0), 0.0)
