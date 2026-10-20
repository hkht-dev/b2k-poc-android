"""Invisible walls at the edge of the Street's ground.

The ground is four slabs (gen_street.py): x -65..65, z -45..45 with the
middle band open east and west. Past them there is nothing at all, and
`Player._track_fall` only measures a fall when it lands, so a player who
walked north past the flats — or drove the car four seconds up the
north-south road — fell for ever, with no pause, no quit and no bottom.
The Grove has had bounds since it was built (tools/gen_grove.py
"BoundsEastWest", "BoundsSouth", "RiverWall"); the Street never did.

Four colliders, no meshes: the player meets an edge they cannot see and
stops, the way they stop at the Grove's. They are tall enough that the
rooftops and the tower's landings are inside them too, so a vault off a
roof at the block's edge lands on the pavement rather than in the void.
"""

from __future__ import annotations

PARENT = "Ground"
# The ground slabs' outer edges, from gen_street.py.
HALF_X, HALF_Z = 65.0, 45.0
# Thickness into the void, and how far up the wall stands: the billboard
# tower's top beam is at y 26, so 40 m clears everything walkable.
THICK, HEIGHT = 2.0, 40.0
# Half the wall's height, so its foot sits a little below the ground.
CENTRE_Y = HEIGHT / 2 - 1.0


def build(b) -> None:
    b.group("Bounds", PARENT)
    sides = (
        ("North", (0.0, CENTRE_Y, -HALF_Z - THICK / 2), (HALF_X * 2 + THICK * 2, HEIGHT, THICK)),
        ("South", (0.0, CENTRE_Y, HALF_Z + THICK / 2), (HALF_X * 2 + THICK * 2, HEIGHT, THICK)),
        ("West", (-HALF_X - THICK / 2, CENTRE_Y, 0.0), (THICK, HEIGHT, HALF_Z * 2)),
        ("East", (HALF_X + THICK / 2, CENTRE_Y, 0.0), (THICK, HEIGHT, HALF_Z * 2)),
    )
    for name, pos, size in sides:
        b.collider(f"Bound{name}", f"{PARENT}/Bounds", size, [(pos, 0.0)])
