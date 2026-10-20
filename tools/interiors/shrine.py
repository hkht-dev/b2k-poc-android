"""The shrine room behind the chai stall: scenes/places/Shrine.tscn.

GDD §5 Hollow Vale: "the shrine room behind Madhuri's chai stall (old
photographs, a lamp, a stone basin)", tucked away, found by following Tulu.
GDD §7 "Investigate" steps 1-3; GDD §8 Scene D: "A small room, one lamp
nearly out, carvings on the walls. Madhuri is refilling the lamp from an
empty jar." GDD §6 "Remembering Krishna": the visit sets `saw_shrine`; here
that is looking at all three photographs (data/dialogue, see
scripts/quest/photograph.gd).

A 6 x 5 m room, lower than the shops, lit by the one lamp (it lives in
scenes/quest/LampPoint.tscn so it can brighten once watered); three
photographs on the east wall (scenes/quest/Photograph.tscn); the lamp on a
plaster stand against the south wall, a stone basin, a cushion before the
lamp; Madhuri by the lamp with her empty jar. The door back to the street
is in the north wall, as in every interior.

PLACEHOLDER: primitives in the street's textures; replaced by the custom
shrine interior of GDD §5 "Reuse plan" and §10 "Asset sourcing plan".
Palette: GDD §10, Hollow Vale row (ochre, dust, timber, rust).
"""

from __future__ import annotations

import math

from gen_interiors import SOUTH, assemble
from scenegen import Builder, xf

W, D = 6.0, 5.0
HEIGHT = 2.8
WALL = 0.3
SPAWN = "shrine_door"
# scenegen.xf writes the basis by rows, so its yaw is the negative of
# Node3D.rotation.y: a figure placed with these faces east or west.
FACE_EAST = math.pi / 2
FACE_WEST = -math.pi / 2
# (line id stem, z along the east wall); the lines are in data/dialogue/en.json.
PHOTOS = (("fountain", -1.6), ("tower", -0.4), ("lamp", 0.8))
LAMP = (0.4, 0.0, 1.95)
MADHURI = (-2.3, 0.0, 1.3)
BASIN = (2.3, 0.0, 1.95)
# Dim: the lamp is the light. assemble() writes the shops' ambient; this room
# takes it down. Each replacement is checked, so a change there fails here
# loudly instead of leaving the shrine lit like a shop.
AMBIENT = (
    (
        "ambient_light_color = Color(0.82, 0.78, 0.72, 1)\n",
        "ambient_light_color = Color(0.6, 0.48, 0.36, 1)\n",
    ),
    ("ambient_light_energy = 0.9\n", "ambient_light_energy = 0.3\n"),
)

EXT = (
    '[ext_resource type="PackedScene" path="res://scenes/npc/Madhuri.tscn" id="madhuri"]\n'
    '[ext_resource type="PackedScene" path="res://scenes/quest/LampPoint.tscn" id="lamp_point"]\n'
    '[ext_resource type="PackedScene" path="res://scenes/quest/Photograph.tscn" id="photograph"]\n'
)


def scene_name() -> str:
    return "Shrine.tscn"


def scene() -> str:
    b = Builder()
    _room(b)
    _shrine(b)
    _photographs(b)
    text = assemble(b, "Shrine", "shrine", (0.14, 0.11, 0.09), extra_ext=EXT)
    for old, new in AMBIENT:
        assert text.count(old) == 1, f"gen_interiors.assemble changed its Environment; update {__file__}"
        text = text.replace(old, new, 1)
    return text


def _room(b: Builder) -> None:
    """Floor, walls, a low timber ceiling, the doorway north, the door back."""
    b.group("Room")
    b.solid("Floor", "Room", (0, -0.1, 0), (W, 0.2, D), "concrete_dust")
    b.detail("Ceiling", "Room", (0, HEIGHT + 0.1, 0), (W + 0.6, 0.2, D + 0.6), "timber")
    b.solid("WallNorth", "Room", (0, HEIGHT / 2, -D / 2 - WALL / 2), (W + WALL * 2, HEIGHT, WALL), "ph_plaster")
    b.solid("WallSouth", "Room", (0, HEIGHT / 2, D / 2 + WALL / 2), (W + WALL * 2, HEIGHT, WALL), "ph_plaster")
    b.solid("WallWest", "Room", (-W / 2 - WALL / 2, HEIGHT / 2, 0), (WALL, HEIGHT, D), "ph_plaster")
    b.solid("WallEast", "Room", (W / 2 + WALL / 2, HEIGHT / 2, 0), (WALL, HEIGHT, D), "ph_plaster")
    # The stall's back door, seen from inside: a dark recess in a timber frame.
    face = -D / 2 + 0.01
    b.detail("Doorway", "Room", (0, 1.1, face - 0.08), (1.3, 2.2, 0.16), "tyre")
    b.detail("FrameL", "Room", (-0.75, 1.15, face), (0.14, 2.3, 0.2), "timber")
    b.detail("FrameR", "Room", (0.75, 1.15, face), (0.14, 2.3, 0.2), "timber")
    b.detail("Lintel", "Room", (0, 2.32, face), (1.7, 0.14, 0.2), "timber")
    # "Carvings on the walls" (Scene D): a row of timber panels, west wall.
    b.multimesh(
        "Carvings", "Room", "BoxMesh_unit", "timber",
        [((-W / 2 + 0.03, 1.45, z), 0.0, (0.05, 0.32, 0.32)) for z in (-1.5, -0.9, -0.3, 0.3, 0.9)],
        shadows=False,
    )
    b.door("DoorOut", "Room", "street", SPAWN, "verb.leave", (0, 0, -D / 2 + 0.9), size=(2.0, 2.2, 1.5))
    b.spawn("SpawnIn", "Room", SPAWN, (0.3, 0, -D / 2 + 2.1), SOUTH)


def _shrine(b: Builder) -> None:
    """The lamp on its stand, the dry basin, the cushion, Madhuri and her jar."""
    b.group("Shrine")
    x, _, z = LAMP
    # A brass lamp on a plaster stand: plinth, body, stem, cup, flame.
    b.solid("Plinth", "Shrine", (x, 0.45, z), (0.5, 0.9, 0.5), "plaster_white")
    b.detail_cyl("LampBody", "Shrine", (x, 1.05, z), 0.15, 0.3, "rust_metal")
    b.detail_cyl("LampStem", "Shrine", (x, 1.3, z), 0.035, 0.2, "rust_metal")
    b.detail_cyl("LampCup", "Shrine", (x, 1.44, z), 0.11, 0.08, "rust_metal")
    b.nodes.append(
        '[node name="Flame" type="MeshInstance3D" parent="Shrine"]\n'
        f"transform = {xf((x, 1.53, z), 0.0, (0.1, 0.14, 0.1))}\n"
        'mesh = SubResource("SphereMesh_unit")\n'
        'surface_material_override/0 = ExtResource("22_road_paint")\n'
        "cast_shadow = 0\n\n"
    )
    # The point the player uses, and the room's one light, at the stand's foot.
    b.nodes.append(
        '[node name="LampPoint" parent="Shrine" instance=ExtResource("lamp_point")]\n'
        "unique_name_in_owner = true\n"
        f"transform = {xf((x, 0, z))}\n\n"
    )
    # The stone basin, dry (Scene D: "The well is dry").
    bx, _, bz = BASIN
    b.detail_cyl("Basin", "Shrine", (bx, 0.2, bz), 0.45, 0.4, "ph_concrete")
    b.detail_cyl("BasinBottom", "Shrine", (bx, 0.405, bz), 0.36, 0.01, "tyre")
    b.collider("BasinBody", "Shrine", (0.9, 0.5, 0.9), [((bx, 0.25, bz), 0.0)])
    # A cushion before the lamp, where the player stands to water it.
    b.detail("Cushion", "Shrine", (x, 0.06, z - 1.05), (0.62, 0.12, 0.62), "coat", yaw=0.25)
    # Madhuri by the lamp, facing it (Scene D: she does not turn round), her
    # empty jar at her feet.
    b.nodes.append(
        '[node name="Madhuri" parent="Shrine" instance=ExtResource("madhuri")]\n'
        "unique_name_in_owner = true\n"
        f"transform = {xf(MADHURI, FACE_EAST)}\n\n"
    )
    b.detail_cyl("Jar", "Shrine", (MADHURI[0] + 0.45, 0.13, MADHURI[2] + 0.35), 0.1, 0.26, "plaster_cream")


def _photographs(b: Builder) -> None:
    """Three old photographs on the east wall, each with its lines (data)."""
    b.group("Photographs")
    for stem, z in PHOTOS:
        b.nodes.append(
            f'[node name="Photo{stem.capitalize()}" parent="Photographs" instance=ExtResource("photograph")]\n'
            "unique_name_in_owner = true\n"
            f"transform = {xf((W / 2 - 0.04, 1.5, z), FACE_WEST)}\n"
            f'entry_lines = PackedStringArray("photo_{stem}_last", "photo_{stem}")\n\n'
        )
