"""Nanda's flat: scenes/places/NandaFlat.tscn, the place "nanda_flat".

GDD §5, Hollow Vale: "four enterable interiors ... Nanda's flat at the end of
the alley". GDD §4, Old Nanda: the recluse who wants to be left alone and
needs to belong again; he lost his brother on the tower years ago.

A small dim 6 x 5 m room: a bed, a shelf of old things, a photograph of two
brothers on the tower (*Look* answers with a thought and sets
`saw_brothers_photo`) and, on the shelf, the broken instrument's missing
string (GDD §7 "Mediate", step 3: "bring him the broken instrument's missing
string (found at Nanda's flat)"). *Pick up* sets `has_sarang_string` and the
player carries "string" (scenes/quest/StringPickup.tscn). The giving happens
at Sarang's corner, which reads `sarang_string_given`; none of that is here.
Bolts on the inside of the door: GDD §5, locks in every household.

The door and spawn point on the street are tools/street_parts/nanda_door.py.
"""

from __future__ import annotations

from gen_interiors import assemble, lights, room
from interiors._props import LOOK_EXT, framed_print, look
from scenegen import Builder

W, D = 6.0, 5.0
F = "Fittings"
STRING_EXT = '[ext_resource type="PackedScene" path="res://scenes/quest/StringPickup.tscn" id="string_pickup"]\n'
# The room is dim (the brief): the one lamp is amber and the ambient light is
# half the shops'. assemble() writes the shops' value; it is replaced below.
AMBIENT_SHOPS = "ambient_light_energy = 0.9"
AMBIENT_HERE = "ambient_light_energy = 0.42"


def scene_name() -> str:
    return "NandaFlat.tscn"


def scene() -> str:
    b = Builder()
    room(b, W, D, "timber", "plaster_ochre", "nanda_door")
    lights(b, [(0.6, 0.6)], colour=(0.72, 0.52, 0.34))
    b.group(F)
    _bed(b)
    _shelf(b)
    _photograph(b)
    _table(b)
    _bolts(b)
    text = assemble(b, "NandaFlat", "nanda_flat", (0.16, 0.14, 0.12), LOOK_EXT + STRING_EXT)
    assert text.count(AMBIENT_SHOPS) == 1, "gen_interiors.assemble changed its ambient light; update nanda_flat.py"
    return text.replace(AMBIENT_SHOPS, AMBIENT_HERE, 1)


def _bed(b: Builder) -> None:
    """A single bed along the east wall, made, the blanket turned down."""
    x = W / 2 - 0.55
    b.solid("Bed", F, (x, 0.17, 0.9), (1.0, 0.34, 2.0), "timber")
    b.solid("Mattress", F, (x, 0.42, 0.9), (0.94, 0.16, 1.9), "cloth_pale", collide=False)
    b.solid("Blanket", F, (x, 0.525, 1.25), (0.96, 0.05, 1.1), "coat", collide=False)
    b.solid("Pillow", F, (x, 0.56, 0.1), (0.5, 0.12, 0.36), "plaster_white", collide=False)


def _shelf(b: Builder) -> None:
    """The shelf of old things on the south wall: four boards between two
    uprights, cans, a tin, books, folded cloth, a crate on the floor beside
    it, and the string, coiled, on the third board."""
    z = D / 2 - 0.2
    for side, x in (("L", -2.2), ("R", -0.2)):
        b.solid(f"Upright{side}", F, (x, 0.85, z), (0.05, 1.7, 0.36), "timber", collide=False)
    b.multimesh("ShelfBoards", F, "BoxMesh_unit", "timber",
                [((-1.2, y, z), 0.0, (2.1, 0.04, 0.36)) for y in (0.3, 0.75, 1.2, 1.6)], shadows=False)
    b.collider("ShelfBody", F, (2.1, 1.7, 0.4), [((-1.2, 0.85, z), 0.0)])
    b.batch("OldCans", F, "can", [((-1.9, 0.32, z), 0.7, (1.4,) * 3), ((-1.0, 0.77, z - 0.05), 2.1, (1.4,) * 3)],
            shadows=False)
    b.batch("OldCrate", F, "crate", [((0.5, 0.0, z - 0.1), 0.4, (1.5,) * 3)], shadows=False)
    b.collider("OldCrateBody", F, (0.6, 0.5, 0.5), [((0.5, 0.25, z - 0.1), 0.4)])
    b.cyl("Tin", F, (-0.6, 0.4, z), 0.08, 0.16, "rust_metal")
    b.solid("Book0", F, (-1.7, 0.88, z), (0.3, 0.22, 0.2), "coat", yaw=0.05, collide=False)
    b.solid("Book1", F, (-1.4, 0.86, z - 0.02), (0.2, 0.18, 0.22), "plaster_cream", yaw=-0.1, collide=False)
    b.solid("FoldedCloth", F, (-0.7, 1.26, z), (0.4, 0.08, 0.3), "cloth_pale", collide=False)
    b.solid("Box", F, (-1.9, 1.7, z), (0.36, 0.16, 0.3), "timber", yaw=0.2, collide=False)
    # The missing string, where it has lain for years.
    b.nodes.append(
        '[node name="StringPickup" parent="Fittings" instance=ExtResource("string_pickup")]\n'
        "unique_name_in_owner = true\n"
        f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -1.6, 1.22, {z - 0.04:g})\n\n"
    )


def _photograph(b: Builder) -> None:
    """Two brothers on the tower's top beam, framed, on the west wall at eye
    height. The only picture in the room."""
    z = -0.5
    mark_x = framed_print(b, "Photo", F, (-W / 2, 1.55, z), 0.56, 0.42, on_x_wall=True)
    b.solid("PhotoTower", F, (mark_x, 1.48, z), (0.02, 0.34, 0.06), "tyre", collide=False)
    b.solid("PhotoBeam", F, (mark_x, 1.66, z), (0.02, 0.03, 0.3), "tyre", collide=False)
    for i, dz in enumerate((-0.06, 0.06)):
        b.solid(f"PhotoBrother{i}", F, (mark_x, 1.725, z + dz), (0.02, 0.1, 0.035), "tyre", collide=False)
    look(b, "PhotoLook", F, "nanda_photo_look", (-W / 2 + 0.65, 0, z), size=(1.3, 2.2, 1.4))


def _table(b: Builder) -> None:
    """A small table by the bed's head, a cup on it, a stool."""
    b.solid("Table", F, (1.3, 0.35, -0.2), (0.7, 0.7, 0.5), "timber")
    b.cyl("Cup", F, (1.2, 0.74, -0.15), 0.04, 0.08, "plaster_white")
    b.solid("Stool", F, (0.6, 0.21, 0.6), (0.36, 0.42, 0.36), "timber")


def _bolts(b: Builder) -> None:
    """Two bolts on the inside of the door: locks in every household."""
    face = -D / 2 + 0.01
    for i, y in enumerate((1.35, 0.6)):
        b.solid(f"Bolt{i}", F, (0.55, y, face + 0.1), (0.26, 0.05, 0.05), "rust_metal", collide=False)
        b.solid(f"BoltKeep{i}", F, (0.76, y, face + 0.1), (0.06, 0.08, 0.07), "rust_metal", collide=False)
