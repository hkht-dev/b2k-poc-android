"""The Tells of the Street (GDD §6 "Tells", §16a "Noticed").

Twelve small, silent wrongnesses, each a prop built from primitives beside a
scenes/quest/Tell.tscn the player can *Look* at. Which tell a node is, is
data on it (`tell_id`, a row of data/tells.json); the sentence it is seen in
is `tell.<id>` in the string table. Nothing here explains, counts or rewards:
a player who looks around finds them, and *Your journey* keeps the sentence.

Placed clear of the other verbs (the fountain's Look, the shop's Pick up,
Tulu's Listen, the bus stop's Sit) so the one button never has to choose.
Nothing peacock blue or magenta (GDD §10, Hollow Vale row): the poster's
feather is a sliver of timber, and only the sentence says what it is.

PLACEHOLDER: primitives with the street's procedural textures; the painted
props of GDD §10 replace them.
"""

from __future__ import annotations

import math

from scenegen import MAT_ID, xf

EXT = (
    '[ext_resource type="PackedScene" path="res://scenes/quest/Tell.tscn" id="tell"]\n'
    '[ext_resource type="Material" path="res://assets/materials/water.tres" id="tell_water"]\n'
    '[ext_resource type="Material" path="res://assets/materials/tell_shadow.tres" id="tell_shadow"]\n'
    '[ext_resource type="Material" path="res://assets/materials/tell_glow.tres" id="tell_glow"]\n'
)

GROUP = "Tells"
KERB_Y = 0.16
# gen_street.py's Sun throws shadows to the north-west; this one lies the
# other way, toward it: a yaw whose +Z points south-east.
TOWARD_SUN = math.atan2(0.5, 0.866)


def _mat(name: str) -> str:
    """ExtResource reference for a street material, or one of this part's own."""
    return f'ExtResource("{MAT_ID[name]}")' if name in MAT_ID else f'ExtResource("{name}")'


def _mesh(b, name, parent, transform, mesh, mat, shadow=True) -> None:
    cast = "" if shadow else "cast_shadow = 0\n"
    b.nodes.append(
        f'[node name="{name}" type="MeshInstance3D" parent="{parent}"]\n'
        f"transform = {transform}\n"
        f'mesh = SubResource("{mesh}")\n'
        f"surface_material_override/0 = {_mat(mat)}\n{cast}\n"
    )


def yaw_xf(pos, yaw, size) -> str:
    """A box turned about Y by `yaw` (Godot's rotation.y) then scaled, as the
    .tscn writes it: the basis row by row. Right for a non-uniform size, which
    scenegen.xf is not."""
    c, s = math.cos(yaw), math.sin(yaw)
    sx, sy, sz = size
    v = [sx * c, 0, sz * s, 0, sy, 0, -sx * s, 0, sz * c, *pos]
    return "Transform3D(" + ", ".join(f"{n:g}" for n in v) + ")"


def roll_xf(pos, angle, size) -> str:
    """A box turned about Z by `angle` (a diamond, a tilted sliver), scaled."""
    c, s = math.cos(angle), math.sin(angle)
    sx, sy, sz = size
    v = [sx * c, -sy * s, 0, sx * s, sy * c, 0, 0, 0, sz, *pos]
    return "Transform3D(" + ", ".join(f"{n:g}" for n in v) + ")"


def face_xf(pos, radius, thickness) -> str:
    """A cylinder whose axis runs along Z: a disc on a wall facing north-south."""
    d = radius * 2
    v = [d, 0, 0, 0, 0, -d, 0, thickness, 0, *pos]
    return "Transform3D(" + ", ".join(f"{n:g}" for n in v) + ")"


def _box(b, name, pos, size, mat, yaw=0.0, shadow=True) -> None:
    """A box, batched (scenegen Builder.detail_mesh); `yaw` is rotation.y."""
    del name  # documentary: a detail is an instance in its bucket, not a node
    b.detail_mesh(GROUP, "BoxMesh_unit", mat, pos, yaw, size, shadow)


def _decal(b, name, pos, size, mat, yaw=0.0) -> None:
    """A flat mark lying on a surface: a thin box that casts no shadow."""
    _box(b, name, pos, (size[0], 0.01, size[1]), mat, yaw, shadow=False)


def _ball(b, name, pos, diameter, mat) -> None:
    del name
    b.detail_mesh(GROUP, "SphereMesh_unit", mat, pos, 0.0, (diameter,) * 3, True)


def _tell(b, tell_id, pos) -> None:
    """The Tell itself: the node the player can *Look* at, by id."""
    b.nodes.append(
        f'[node name="Tell_{tell_id}" parent="{GROUP}" instance=ExtResource("tell")]\n'
        f"transform = {xf(pos)}\n"
        f'tell_id = "{tell_id}"\n\n'
    )


def build(b) -> None:
    b.group(GROUP)

    # The clock over the chai stall (the stall's front faces south at z = -7):
    # a rim, a face, two hands. It stops while the hum is held: requires_humming.
    _mesh(b, "ClockRim", GROUP, face_xf((15.05, 2.3, -6.97), 0.33, 0.04), "CylinderMesh_unit", "rust_metal")
    _mesh(b, "ClockFace", GROUP, face_xf((15.05, 2.3, -6.94), 0.29, 0.03), "CylinderMesh_unit", "plaster_white")
    _box(b, "ClockHour", (15.05, 2.37, -6.92), (0.03, 0.15, 0.01), "tyre", shadow=False)
    _box(b, "ClockMinute", (15.15, 2.3, -6.92), (0.2, 0.025, 0.01), "tyre", shadow=False)
    _ball(b, "ClockPin", (15.05, 2.3, -6.915), 0.03, "tyre")
    _tell(b, "clock_chai_stall", (15.0, 0.0, -5.8))

    # A puddle on the pavement west of Gopal Seth's shop, a small world in it.
    _mesh(b, "Puddle", GROUP, xf((-21.0, 0.006, 1.0), 0.0, (1.8, 0.012, 1.8)), "CylinderMesh_unit", "tell_water", shadow=False)
    _ball(b, "PuddleWorld", (-20.9, 0.05, 1.05), 0.1, "plaster_cream")
    _ball(b, "PuddleMoon", (-21.1, 0.04, 0.9), 0.05, "tyre")
    _tell(b, "puddle_world", (-21.0, 0.0, 1.0))

    # A flat's window that gives back a light the street does not have: a faint
    # warm quad just in front of the barred pane (Flat3, east window).
    _box(b, "WindowGlow", (7.7, 2.3, -18.8), (0.8, 0.6, 0.01), "tell_glow", shadow=False)
    _tell(b, "window_glow", (7.6, 0.0, -17.5))

    # A poster between two windows of Flat2: a figure, and a feather in its hair
    # if you look twice. Timber, not peacock blue.
    _box(b, "PosterFrame", (-11.75, 1.5, -18.98), (1.0, 1.4, 0.03), "timber", shadow=False)
    _box(b, "Poster", (-11.75, 1.5, -18.96), (0.9, 1.3, 0.02), "sign", shadow=False)
    _box(b, "PosterFigure", (-11.75, 1.35, -18.945), (0.28, 0.7, 0.01), "coat", shadow=False)
    _ball(b, "PosterHead", (-11.75, 1.84, -18.945), 0.17, "skin")
    _mesh(b, "PosterFeather", GROUP, roll_xf((-11.64, 2.02, -18.94), -0.5, (0.035, 0.22, 0.01)), "BoxMesh_unit", "timber", shadow=False)
    _tell(b, "poster_feather", (-11.75, 0.0, -17.5))

    # A doorway in the tower's foot with a cow-shaped shadow lying out of it,
    # and nothing in the doorway.
    _box(b, "DoorwayDark", (-33.0, 1.2, -18.46), (1.4, 2.4, 0.08), "tyre", shadow=False)
    _box(b, "DoorwayPostL", (-33.76, 1.25, -18.44), (0.12, 2.5, 0.14), "timber")
    _box(b, "DoorwayPostR", (-32.24, 1.25, -18.44), (0.12, 2.5, 0.14), "timber")
    _box(b, "DoorwayLintel", (-33.0, 2.46, -18.44), (1.64, 0.12, 0.14), "timber")
    _decal(b, "CowBody", (-33.0, 0.012, -17.35), (1.7, 0.75), "tell_shadow")
    _decal(b, "CowHead", (-32.05, 0.012, -17.0), (0.55, 0.42), "tell_shadow")
    for i, x in enumerate((-27.7, -27.35, -26.65, -26.3)):
        _decal(b, f"CowLeg{i}", (x, 0.012, -17.95), (0.14, 0.5), "tell_shadow")
    _tell(b, "cow_shadow", (-33.0, 0.0, -16.6))

    # A kite over the crossing with no string: a diamond on two spars, a tail.
    _mesh(b, "Kite", GROUP, roll_xf((27.0, 6.8, 11.5), math.pi / 4, (0.9, 0.9, 0.02)), "BoxMesh_unit", "cloth_pale")
    _box(b, "KiteSparUp", (27.0, 6.8, 11.49), (0.03, 1.27, 0.03), "timber")
    _box(b, "KiteSparAcross", (27.0, 6.8, 11.49), (1.27, 0.03, 0.03), "timber")
    for i, (dx, dy) in enumerate(((0.0, -0.78), (0.1, -1.02), (-0.06, -1.26))):
        _box(b, f"KiteTail{i}", (27.0 + dx, 6.8 + dy, 11.5), (0.12, 0.08, 0.01), "cloth_pale", shadow=False)
    _tell(b, "kite_no_string", (27.0, KERB_Y, 9.0))

    # A bird on the westernmost cable (its midpoint is (-52, 6.6, 4)) that never moves.
    _box(b, "BirdBody", (-52.0, 6.68, 4.0), (0.14, 0.12, 0.26), "tyre")
    _ball(b, "BirdHead", (-52.0, 6.78, 3.86), 0.09, "tyre")
    _tell(b, "bird_still", (-52.0, 0.0, 4.4))

    # The lamp post at (42, 8.2) throws its shadow toward the sun, along the kerb.
    _decal(b, "WrongShadow", (42.65, KERB_Y + 0.006, 9.33), (0.28, 2.6), "tell_shadow", yaw=TOWARD_SUN)
    _tell(b, "shadow_toward_sun", (43.6, KERB_Y, 8.9))

    # Three chalk marks on the pavement north of the fountain, each a little
    # further on than the last, like Tulu's notes.
    for i, (x, z) in enumerate(((-5.0, -10.3), (-4.5, -10.65), (-4.0, -11.0))):
        _decal(b, f"Chalk{i}", (x, 0.006, z), (0.32, 0.07), "road_paint")
    _tell(b, "chalk_three_notes", (-4.5, 0.0, -10.6))

    # A jasmine flower in the dust by the fence, where nothing grows.
    _ball(b, "JasmineHeart", (-24.5, 0.045, 7.0), 0.09, "plaster_white")
    for i in range(5):
        a = i * 2 * math.pi / 5
        _decal(b, f"JasminePetal{i}", (-24.5 + 0.09 * math.sin(a), 0.02, 7.0 + 0.09 * math.cos(a)), (0.07, 0.12), "plaster_white", yaw=a)
    _box(b, "JasmineStem", (-24.5, 0.01, 7.16), (0.012, 0.01, 0.18), "timber", shadow=False)
    _tell(b, "jasmine_dust", (-24.5, 0.0, 6.6))

    # Wet footprints, small ones, leading away from the dry fountain across the
    # south kerb.
    for i, (x, z) in enumerate(((0.35, 7.85), (0.7, 8.4), (0.35, 8.95), (0.7, 9.5), (0.35, 10.05))):
        _decal(b, f"Footprint{i}", (x, KERB_Y + 0.006, z), (0.11, 0.24), "tell_shadow")
    _tell(b, "footprints_wet", (0.5, KERB_Y, 8.9))

    # The covered car's tarpaulin, a loose corner of it on the kerb under a brick.
    _box(b, "TarpCorner", (52.6, KERB_Y + 0.025, 9.9), (0.9, 0.05, 0.55), "cloth_pale", yaw=0.3)
    _box(b, "TarpBrick", (52.95, KERB_Y + 0.05, 9.75), (0.22, 0.1, 0.11), "brick", yaw=0.3)
    _tell(b, "tarp_breath", (52.3, KERB_Y, 9.1))
