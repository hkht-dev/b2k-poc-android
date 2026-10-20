#!/usr/bin/env python3
"""Generate scenes/street/Street.tscn — Hollow Vale's one block.

The street is a few hundred primitives placed by rules, and the rules are
easier to read and change here than as a 1,500-line scene file. Run this after
editing it; the .tscn it writes is an ordinary Godot scene and is committed.

    python3 tools/gen_street.py           # writes scenes/street/Street.tscn
    python3 tools/gen_street.py --check   # fails if the committed scene is stale

Layout: X east, Z south, Y up. The fountain is at the origin; the ground is
four slabs whose gap is exactly the fountain's footprint. Repeated primitives
(road dashes, window bars, fence rails, rooftop tanks, cables) are MultiMeshes:
one draw call each, however many there are. Repeated models (lamp posts,
trees, hydrants, litter — CC0 .glb files fetched by tools/fetch_quaternius.py,
tools/fetch_kenney.py and tools/fetch_polyhaven.py, see docs/RIGHTS_REGISTER.md) go through
scripts/street/model_batch.gd, which does the same for an imported scene.
Budget (amendment §C): under 200 draw calls and 150k triangles per frame.
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "scenes" / "street" / "Street.tscn"

MATS = [
    "plaster_ochre", "plaster_white", "plaster_cream", "brick", "concrete_dust",
    "asphalt", "timber", "corrugated", "rust_metal", "coat", "cloth_pale", "skin",
    "road_paint", "tyre",
    # CC0, Poly Haven, via tools/fetch_polyhaven.py — see docs/RIGHTS_REGISTER.md
    "ph_asphalt", "ph_concrete", "ph_plaster", "ph_brick", "ph_corrugated",
    "sign", "canopy",
]
# Real-time shadow as the stand-in until the LightmapGI below is baked in the
# editor (docs/BRIEF_AMENDMENT_1.md §B5 asks for baked; see docs/DECISIONS.md).
REALTIME_SHADOW_STANDIN = True
MAT_ID = {m: f"{i + 10}_{m}" for i, m in enumerate(MATS)}

# CC0 models under assets/thirdparty/, each with a row in docs/RIGHTS_REGISTER.md.
# PLACEHOLDER: stand-ins for the painted stylised props of GDD §10.
MODELS = {
    # Quaternius, via tools/fetch_quaternius.py (one mesh a car; textured trees)
    "car_normal1": "quaternius/realistic-car-pack/NormalCar1.glb",
    "car_normal2": "quaternius/realistic-car-pack/NormalCar2.glb",
    "car_suv": "quaternius/realistic-car-pack/SUV.glb",
    "car_taxi": "quaternius/realistic-car-pack/Taxi.glb",
    "car_sports": "quaternius/realistic-car-pack/SportsCar.glb",
    "car_sports2": "quaternius/realistic-car-pack/SportsCar2.glb",
    "tree_1": "quaternius/textured-stylized-trees/Tree_1.glb",
    "tree_3": "quaternius/textured-stylized-trees/Tree_3.glb",
    "tree_5": "quaternius/textured-stylized-trees/Tree_5.glb",
    "birch_1": "quaternius/textured-stylized-trees/Birch_1.glb",
    "birch_4": "quaternius/textured-stylized-trees/Birch_4.glb",
    "pine_2": "quaternius/textured-stylized-trees/Pine_2.glb",
    # Kenney, via tools/fetch_kenney.py
    "bush": "kenney/nature-kit/plant_bushLarge.glb",
    # Poly Haven, via tools/fetch_polyhaven.py
    "lamp": "polyhaven/models/street_lamp_01/street_lamp_01.glb",
    "bench": "polyhaven/models/modular_street_seating/modular_street_seating.glb",
    "hydrant": "polyhaven/models/fire_hydrant/fire_hydrant.glb",
    "covered_car": "polyhaven/models/covered_car/covered_car.glb",
    "can": "polyhaven/models/can_rusted/can_rusted.glb",
    "crate": "polyhaven/models/plastic_crate_01/plastic_crate_01.glb",
    "manhole": "polyhaven/models/water_manhole_cover/water_manhole_cover.glb",
}
MODEL_ID = {m: f"model_{m}" for m in MODELS}
# Quaternius' cars are life-size (1.8 x 4.2 m) and face +Z (headlights at
# +Z); movers face -Z, so a moving car is turned half round.
CAR_SCALE = 1.0

nodes: list[str] = []
shapes: dict[tuple, str] = {}
multimeshes: list[str] = []


def xf(pos=(0, 0, 0), yaw=0.0, scale=(1, 1, 1)) -> str:
    c, s = math.cos(yaw), math.sin(yaw)
    v = [c * scale[0], 0, -s * scale[0], 0, scale[1], 0, s * scale[2], 0, c * scale[2], *pos]
    return "Transform3D(" + ", ".join(f"{n:g}" for n in v) + ")"


def shape_id(size) -> str:
    key = tuple(round(v, 4) for v in size)
    if key not in shapes:
        shapes[key] = f"BoxShape3D_{len(shapes)}"
    return shapes[key]


def solid(name, parent, pos, size, mat, yaw=0.0, collide=True) -> None:
    """A box. With collision it is a StaticBody3D; without, a bare mesh."""
    if collide:
        nodes.append(
            f'[node name="{name}" type="StaticBody3D" parent="{parent}"]\n'
            f"transform = {xf(pos, yaw)}\ncollision_layer = 1\ncollision_mask = 0\n\n"
            f'[node name="Shape" type="CollisionShape3D" parent="{parent}/{name}"]\n'
            f'shape = SubResource("{shape_id(size)}")\n\n'
            f'[node name="Mesh" type="MeshInstance3D" parent="{parent}/{name}"]\n'
            f"transform = {xf((0, 0, 0), 0.0, size)}\n"
            f'mesh = SubResource("BoxMesh_unit")\n'
            f'surface_material_override/0 = ExtResource("{MAT_ID[mat]}")\n\n'
        )
    else:
        nodes.append(
            f'[node name="{name}" type="MeshInstance3D" parent="{parent}"]\n'
            f"transform = {xf(pos, yaw, size)}\n"
            f'mesh = SubResource("BoxMesh_unit")\n'
            f'surface_material_override/0 = ExtResource("{MAT_ID[mat]}")\n\n'
        )


def cyl(name, parent, pos, radius, height, mat, yaw=0.0, lay=False) -> None:
    """A cylinder; `lay` rolls it onto its side along X (a wheel, a tank)."""
    if lay:
        # rotate 90 degrees about Z: the cylinder's axis becomes X
        v = [0, height, 0, -radius * 2, 0, 0, 0, 0, radius * 2, *pos]
        if yaw:
            c, s = math.cos(yaw), math.sin(yaw)
            bx = (0, height, 0)
            by = (-radius * 2 * c, 0, radius * 2 * s)
            bz = (radius * 2 * s, 0, radius * 2 * c)
            v = [*bx, *by, *bz, *pos]
        t = "Transform3D(" + ", ".join(f"{n:g}" for n in v) + ")"
    else:
        t = xf(pos, yaw, (radius * 2, height, radius * 2))
    nodes.append(
        f'[node name="{name}" type="MeshInstance3D" parent="{parent}"]\n'
        f"transform = {t}\n"
        f'mesh = SubResource("CylinderMesh_unit")\n'
        f'surface_material_override/0 = ExtResource("{MAT_ID[mat]}")\n\n'
    )


def group(name, parent=".") -> None:
    nodes.append(f'[node name="{name}" type="Node3D" parent="{parent}"]\n\n')


def multimesh(name, parent, mesh_id, mat, instances, shadows=True) -> None:
    """One draw call for every instance. Each instance is (pos, yaw, scale)."""
    floats = []
    for pos, yaw, scale in instances:
        c, s = math.cos(yaw), math.sin(yaw)
        sx, sy, sz = scale
        # Godot's 3D MultiMesh buffer: 12 floats per instance, the 3x4 matrix
        # row by row: (bx.x, by.x, bz.x, o.x, bx.y, by.y, bz.y, o.y, bx.z, ...).
        floats += [c * sx, 0, s * sz, pos[0], 0, sy, 0, pos[1], -s * sx, 0, c * sz, pos[2]]
    mm_id = f"MultiMesh_{name}"
    multimeshes.append(
        f'[sub_resource type="MultiMesh" id="{mm_id}"]\n'
        f"transform_format = 1\n"
        f'mesh = SubResource("{mesh_id}")\n'
        f"instance_count = {len(instances)}\n"
        f"buffer = PackedFloat32Array({', '.join(f'{f:g}' for f in floats)})\n\n"
    )
    cast = "" if shadows else "cast_shadow = 0\n"
    nodes.append(
        f'[node name="{name}" type="MultiMeshInstance3D" parent="{parent}"]\n'
        f'multimesh = SubResource("{mm_id}")\n'
        f'material_override = ExtResource("{MAT_ID[mat]}")\n{cast}\n'
    )


def instance_floats(instances) -> str:
    floats = []
    for pos, yaw, scale in instances:
        c, s = math.cos(yaw), math.sin(yaw)
        sx, sy, sz = scale
        floats += [c * sx, 0, s * sz, pos[0], 0, sy, 0, pos[1], -s * sx, 0, c * sz, pos[2]]
    return ", ".join(f"{f:g}" for f in floats)


def batch(name, parent, model, instances, shadows=True) -> None:
    """Many copies of a CC0 model, drawn by ModelBatch: one draw call per
    surface. Each instance is (pos, yaw, scale)."""
    cast = "" if shadows else "cast_shadow = false\n"
    nodes.append(
        f'[node name="{name}" type="Node3D" parent="{parent}"]\n'
        f'script = ExtResource("batch")\n'
        f'scene = ExtResource("{MODEL_ID[model]}")\n'
        f"transforms = PackedFloat32Array({instance_floats(instances)})\n{cast}\n"
    )


def model(name, parent, which, pos, yaw=0.0, scale=1.0) -> None:
    """One copy of a CC0 model, instanced directly (things that move, one-offs)."""
    nodes.append(
        f'[node name="{name}" parent="{parent}" instance=ExtResource("{MODEL_ID[which]}")]\n'
        f"transform = {xf(pos, yaw, (scale, scale, scale))}\n\n"
    )


def collider(name, parent, size, placements) -> None:
    """Collision with no mesh: one StaticBody3D with a box per placement
    (pos, yaw), for props whose look comes from a model or a MultiMesh."""
    nodes.append(
        f'[node name="{name}" type="StaticBody3D" parent="{parent}"]\n'
        f"collision_layer = 1\ncollision_mask = 0\n\n"
    )
    for i, (pos, yaw) in enumerate(placements):
        nodes.append(
            f'[node name="Shape{i}" type="CollisionShape3D" parent="{parent}/{name}"]\n'
            f"transform = {xf(pos, yaw)}\n"
            f'shape = SubResource("{shape_id(size)}")\n\n'
        )


# Kenney's animated-characters skins (pack -> skins), all on the same body;
# docs/RIGHTS_REGISTER.md. The player wears humanMaleA (Player.tscn) and
# Tulu skaterMaleA (Tulu.tscn); the pedestrians cycle through the rest.
SKIN_PACKS = {
    "animated-characters-retro": ["humanFemaleA", "humanMaleA"],
    "animated-characters-protagonists": ["criminalMaleA", "skaterFemaleA", "skaterMaleA"],
    "animated-characters-survivors": ["survivorFemaleA", "survivorMaleB"],
}
SKIN_PATH = {skin: f"{pack}/{skin}.png" for pack, skins in SKIN_PACKS.items() for skin in skins}
PEDESTRIAN_SKINS = ["humanFemaleA", "criminalMaleA", "skaterFemaleA", "survivorFemaleA", "survivorMaleB", "skaterMaleA"]


def figure(name, parent, skin, pos=(0, 0, 0), script_props="", scale=1.0) -> None:
    """A rigged human (scenes/characters/Character.tscn) with the given skin.
    Pedestrians use it; the player's and Tulu's are instanced in their scenes."""
    nodes.append(
        f'[node name="{name}" type="Node3D" parent="{parent}"]\n'
        f"transform = {xf(pos, 0.0, (scale, scale, scale))}\n{script_props}\n"
        f'[node name="Figure" parent="{parent}/{name}" instance=ExtResource("8_character")]\n'
        f'skin = ExtResource("skin_{skin}")\n\n'
    )


# ================================================================ the block

# --- ground, roads, pavements ------------------------------------------------
group("Ground")
solid("GroundNorth", "Ground", (0, -0.5, -26), (130, 1, 38), "concrete_dust")
solid("GroundSouth", "Ground", (0, -0.5, 26), (130, 1, 38), "concrete_dust")
solid("GroundWest", "Ground", (-36, -0.5, 0), (58, 1, 14), "concrete_dust")
solid("GroundEast", "Ground", (36, -0.5, 0), (58, 1, 14), "concrete_dust")
solid("RoadEastWest", "Ground", (0, 0.01, 16), (130, 0.02, 11), "ph_asphalt", collide=False)
solid("RoadNorthSouth", "Ground", (30, 0.01, 0), (11, 0.02, 90), "ph_asphalt", collide=False)
# Kerbs: a raised pavement either side of each road reads as a city, and the
# step gives the player's feet something to do.
for z in (9.0, 23.0):
    solid(f"KerbEW{z:g}", "Ground", (0, 0.08, z), (130, 0.16, 3.0), "ph_concrete")
for x in (23.0, 37.0):
    solid(f"KerbNS{x:g}", "Ground", (x, 0.08, 0), (3.0, 0.16, 90), "ph_concrete")

# Road markings: one MultiMesh of dashes per road.
multimesh(
    "DashesEW", "Ground", "BoxMesh_unit", "road_paint",
    [((x, 0.025, 16), 0.0, (2.2, 0.02, 0.14)) for x in range(-62, 63, 5)], shadows=False,
)
multimesh(
    "DashesNS", "Ground", "BoxMesh_unit", "road_paint",
    [((30, 0.025, z), 0.0, (0.14, 0.02, 2.2)) for z in range(-42, 45, 5)], shadows=False,
)
batch("Manholes", "Ground", "manhole",
      [((x, 0.05, z), yaw, (1, 1, 1)) for x, z, yaw in ((-22, 18.6, 0.3), (12, 13.4, 1.9), (27.4, -24, 0.9), (32.6, 30, 2.5))],
      shadows=False)

# --- the dry fountain --------------------------------------------------------
# A round public fountain, dry (GDD §4 Hollow Vale): a sunk basin the player
# surfaces in, a stone lip round it, a tiered column in the middle, a shallow
# step of pavement round the outside. The ground gap is the 14 m square; the
# step boxes fill its corners up to the lip so no seam shows.
group("Fountain")
BASIN_R, LIP_R, FLOOR_Y, STEP_Y = 5.6, 7.0, -0.5, -0.15
solid("Floor", "Fountain", (0, -1.25, 0), (14, 0.3, 14), "concrete_dust")
cyl("Basin", "Fountain", (0, (FLOOR_Y - 1.25) / 2, 0), LIP_R, FLOOR_Y + 1.25, "ph_concrete")
nodes.append(
    '[node name="BasinBody" type="StaticBody3D" parent="Fountain"]\n'
    "collision_layer = 1\ncollision_mask = 0\n\n"
    '[node name="Shape" type="CollisionShape3D" parent="Fountain/BasinBody"]\n'
    f"transform = {xf((0, (FLOOR_Y - 1.25) / 2, 0))}\n"
    'shape = SubResource("CylinderShape3D_basin")\n\n'
)
# The lip: a torus, squashed a little taller than round, sitting in the floor.
nodes.append(
    '[node name="Lip" type="MeshInstance3D" parent="Fountain"]\n'
    f"transform = {xf((0, -0.1, 0), 0.0, (1, 1.1, 1))}\n"
    'mesh = SubResource("TorusMesh_lip")\n'
    f'surface_material_override/0 = ExtResource("{MAT_ID["concrete_dust"]}")\n\n'
)
LIP_SEGMENTS = 24
collider(
    "LipBody", "Fountain", (1.9, 1.1, LIP_R - BASIN_R - 0.1),
    [((6.35 * math.sin(a), 0.05, 6.35 * math.cos(a)), a)
     for a in (i * 2 * math.pi / LIP_SEGMENTS for i in range(LIP_SEGMENTS))],
)
# The step: 0.15 m down from the pavement, round the lip, out to the gap's edge.
for name, pos, size in (
    ("StepN", (0, (STEP_Y - 1.1) / 2, -6.3), (8.2, 1.1 + STEP_Y, 1.4)),
    ("StepS", (0, (STEP_Y - 1.1) / 2, 6.3), (8.2, 1.1 + STEP_Y, 1.4)),
    ("StepW", (-6.3, (STEP_Y - 1.1) / 2, 0), (1.4, 1.1 + STEP_Y, 8.2)),
    ("StepE", (6.3, (STEP_Y - 1.1) / 2, 0), (1.4, 1.1 + STEP_Y, 8.2)),
    ("StepNE", (5.55, (STEP_Y - 1.1) / 2, -5.55), (2.9, 1.1 + STEP_Y, 2.9)),
    ("StepNW", (-5.55, (STEP_Y - 1.1) / 2, -5.55), (2.9, 1.1 + STEP_Y, 2.9)),
    ("StepSE", (5.55, (STEP_Y - 1.1) / 2, 5.55), (2.9, 1.1 + STEP_Y, 2.9)),
    ("StepSW", (-5.55, (STEP_Y - 1.1) / 2, 5.55), (2.9, 1.1 + STEP_Y, 2.9)),
):
    solid(name, "Fountain", pos, size, "ph_concrete")
# The column: pedestal, shaft, two dry bowls, a spout that gives nothing.
cyl("Pedestal", "Fountain", (0, FLOOR_Y + 0.15, 0), 1.3, 0.3, "ph_concrete")
cyl("Shaft", "Fountain", (0, 1.0, 0), 0.32, 2.4, "plaster_white")
for name, y, radius, height in (("LowerBowlUnder", 1.3, 1.9, 0.5), ("UpperBowlUnder", 2.35, 1.1, 0.3)):
    nodes.append(
        f'[node name="{name}" type="MeshInstance3D" parent="Fountain"]\n'
        f"transform = {xf((0, y, 0), 0.0, (radius * 2, height, radius * 2))}\n"
        'mesh = SubResource("ConeMesh_unit")\n'
        f'surface_material_override/0 = ExtResource("{MAT_ID["plaster_white"]}")\n\n'
    )
cyl("LowerBowl", "Fountain", (0, 1.64, 0), 1.9, 0.18, "plaster_white")
cyl("LowerBowlFloor", "Fountain", (0, 1.75, 0), 1.72, 0.04, "concrete_dust")
cyl("UpperBowl", "Fountain", (0, 2.57, 0), 1.1, 0.14, "plaster_white")
cyl("UpperBowlFloor", "Fountain", (0, 2.66, 0), 0.95, 0.04, "concrete_dust")
cyl("Spout", "Fountain", (0, 2.9, 0), 0.08, 0.5, "rust_metal")
nodes.append(
    '[node name="Finial" type="MeshInstance3D" parent="Fountain"]\n'
    f"transform = {xf((0, 3.3, 0), 0.0, (0.5, 0.5, 0.5))}\n"
    'mesh = SubResource("SphereMesh_unit")\n'
    f'surface_material_override/0 = ExtResource("{MAT_ID["plaster_white"]}")\n\n'
)
collider("ColumnBody", "Fountain", (2.6, 2.2, 2.6), [((0, FLOOR_Y + 1.1, 0), 0.0)])
# Dry for long enough to collect litter.
nodes.append(
    '[node name="FountainPoint" parent="Fountain" instance=ExtResource("13_fountain_point")]\n'
    "unique_name_in_owner = true\n"
    f"transform = {xf((0, FLOOR_Y, 0))}\n\n"
)
batch("Litter", "Fountain", "can",
      [((1.8, FLOOR_Y, -1.2), 0.4, (1.4, 1.4, 1.4)), ((-2.6, FLOOR_Y, 2.1), 2.0, (1.4, 1.4, 1.4)),
       ((3.9, FLOOR_Y, 2.8), 1.1, (1.4, 1.4, 1.4)), ((-4.1, FLOOR_Y, -1.6), 2.9, (1.4, 1.4, 1.4))],
      shadows=False)

# --- Gopal Seth's shop -------------------------------------------------------
group("Shop")
solid("Back", "Shop", (-14, 2.0, -4.2), (10, 4, 0.4), "plaster_ochre")
solid("Left", "Shop", (-18.8, 2.0, -1.0), (0.4, 4, 6.8), "plaster_ochre")
solid("Right", "Shop", (-9.2, 2.0, -1.0), (0.4, 4, 6.8), "plaster_ochre")
solid("Roof", "Shop", (-14, 4.1, -1.0), (10.4, 0.3, 7.2), "ph_corrugated")
solid("Counter", "Shop", (-14, 0.5, 1.9), (8.4, 1.0, 0.6), "timber")
solid("Awning", "Shop", (-14, 3.55, 2.9), (10.6, 0.08, 2.4), "rust_metal", collide=False)
solid("SignBoard", "Shop", (-14, 4.6, 2.3), (7.0, 0.9, 0.12), "sign", collide=False)
solid("SignFrame", "Shop", (-14, 4.6, 2.22), (7.3, 1.1, 0.06), "timber", collide=False)
# Water cans, stacked where the street can see them (§4.4): a row on the
# pavement in front of the counter that the player can *Pick up* from
# (scripts/quest/can_stack.gd hides one per pick-up), and more behind it.
nodes.append(
    '[node name="CanStack" type="Node3D" parent="Shop"]\n'
    'script = ExtResource("11_can_stack")\n\n'
    '[node name="PickUp" type="Area3D" parent="Shop/CanStack"]\n'
    "unique_name_in_owner = true\n"
    'script = ExtResource("2_interact")\n'
    'verb_id = "verb.pick_up"\n\n'
    '[node name="Shape" type="CollisionShape3D" parent="Shop/CanStack/PickUp"]\n'
    f"transform = {xf((-14, 1.0, 3.4))}\n"
    'shape = SubResource("BoxShape3D_cans")\n\n'
)
for i in range(6):
    cyl(f"Can{i}", "Shop/CanStack", (-17.5 + i * 1.4, 0.35, 3.3), 0.33, 0.7, "rust_metal")
for i in range(6, 12):
    col, row = (i - 6) % 3, (i - 6) // 3
    cyl(f"Can{i}", "Shop/CanStack", (-16.4 + col * 2.4, 0.35, -2.6 + row * 1.2), 0.33, 0.7, "rust_metal")
# Gopal Seth, behind the counter, facing the street.
nodes.append(
    '[node name="Gopal" parent="Shop" instance=ExtResource("12_gopal")]\n'
    "unique_name_in_owner = true\n"
    f"transform = {xf((-13.2, 0, 0.9), math.pi)}\n\n"
)
# Delivery crates stacked by the counter's end.
CRATE = 1.5  # the model is 0.3 x 0.26 x 0.41 m; a crate, at this scale
batch("Crates", "Shop", "crate",
      [((-18.6, 0, 3.1), 0.1, (CRATE,) * 3), ((-18.6, 0.39, 3.1), 0.5, (CRATE,) * 3),
       ((-17.9, 0, 3.4), -0.2, (CRATE,) * 3), ((-18.6, 0.78, 3.1), -0.3, (CRATE,) * 3),
       ((-9.4, 0, 3.0), 1.4, (CRATE,) * 3), ((-9.4, 0.39, 3.0), 1.7, (CRATE,) * 3)])
collider("CrateBody", "Shop", (1.3, 1.2, 0.9), [((-18.3, 0.6, 3.2), 0.0), ((-9.4, 0.6, 3.0), 0.0)])

# --- the chai stall ----------------------------------------------------------
group("ChaiStall")
solid("Body", "ChaiStall", (13, 1.4, -9), (5, 2.8, 4), "plaster_cream")
solid("Roof", "ChaiStall", (13, 2.95, -9), (5.8, 0.3, 4.8), "ph_corrugated")
solid("StallSign", "ChaiStall", (13, 3.5, -6.9), (3.4, 0.6, 0.1), "sign", collide=False)
solid("Hatch", "ChaiStall", (13, 1.6, -6.95), (3.2, 1.4, 0.1), "timber", collide=False)
solid("Shelf", "ChaiStall", (13, 0.9, -6.8), (3.6, 0.1, 0.5), "timber", collide=False)
solid("BackDoor", "ChaiStall", (13, 1.05, -11.05), (1.3, 2.1, 0.12), "rust_metal", collide=False)

# --- the traffic light -------------------------------------------------------
group("TrafficLight")
solid("Pole", "TrafficLight", (25.5, 3.0, 14), (0.35, 6, 0.35), "rust_metal")
solid("Beam", "TrafficLight", (29.5, 5.7, 14), (8.4, 0.3, 0.3), "rust_metal", collide=False)
solid("Housing", "TrafficLight", (32.6, 5.1, 14), (0.5, 1.2, 0.45), "tyre", collide=False)
for i, y in enumerate((5.45, 5.1, 4.75)):
    cyl(f"Lamp{i}", "TrafficLight", (32.6, y, 14.2), 0.13, 0.2, "road_paint")
# The Glimpse point (§4.5): the silhouette sits on the beam facing the
# fountain; its feather falls on the pavement below the pole.
nodes.append(
    '[node name="Glimpse" parent="TrafficLight" instance=ExtResource("14_glimpse")]\n'
    "unique_name_in_owner = true\n"
    f"transform = {xf((29.5, 5.85, 14.0), math.pi / 2)}\n\n"
)

# --- the billboard tower -----------------------------------------------------
group("Tower")
solid("Block", "Tower", (-31, 7.0, -26), (15, 14, 15), "ph_brick")
solid("Parapet", "Tower", (-31, 14.2, -26), (15.6, 0.5, 15.6), "concrete_dust", collide=False)
for i, (dx, dz) in enumerate(((-5, -5), (5, -5), (-5, 5), (5, 5))):
    solid(f"Leg{i}", "Tower", (-31 + dx, 17.5, -26 + dz), (0.5, 7, 0.5), "rust_metal")
for i, (dx, dz) in enumerate(((0, -5), (0, 5), (-5, 0), (5, 0))):
    solid(f"Brace{i}", "Tower", (-31 + dx, 17.5, -26 + dz), (10 if dz else 0.3, 0.3, 0.3 if dz else 10), "rust_metal", collide=False)
solid("Billboard", "Tower", (-31, 22.5, -26), (13, 6, 0.4), "plaster_white", collide=False)
solid("BillboardFrame", "Tower", (-31, 22.5, -26.3), (13.6, 6.6, 0.2), "rust_metal", collide=False)

# --- flats along the block ---------------------------------------------------
group("Flats")
north = [(-62, -22), (-48, -22), (-10, -24), (4, -24), (18, -24), (46, -22)]
south = [(-56, 30), (-40, 30), (-22, 30), (2, 32), (16, 32), (48, 30)]
skins = ["plaster_ochre", "brick", "plaster_white", "ph_plaster", "plaster_cream", "ph_brick"]
bars, panes, tanks, acs, ledges = [], [], [], [], []
for i, (x, z) in enumerate(north + south):
    is_north = i < len(north)
    h = 8 if is_north else 7
    w, d = (11, 10) if is_north else (12, 10)
    y = h / 2
    solid(f"Flat{i}", "Flats", (x, y, z), (w, h, d), skins[i % len(skins)])
    solid(f"Flat{i}Parapet", "Flats", (x, h + 0.2, z), (w + 0.5, 0.4, d + 0.5), "concrete_dust", collide=False)
    face_z = z + d / 2 + 0.06 if is_north else z - d / 2 - 0.06
    for floor_ in range(2):
        for wdx in range(3):
            wx, wy = x - 3.5 + wdx * 3.5, 2.2 + floor_ * 3.2
            # A dark pane with three thin bars across it: a barred window,
            # not an orange square.
            panes.append(((wx, wy, face_z), 0.0, (1.5, 1.3, 0.08)))
            for bdx in (-0.45, 0.0, 0.45):
                bars.append(((wx + bdx, wy, face_z + (0.08 if is_north else -0.08)), 0.0, (0.06, 1.3, 0.06)))
            ledges.append(((wx, wy - 0.75, face_z + (0.2 if is_north else -0.2)), 0.0, (1.9, 0.12, 0.5)))
    tanks.append(((x + 3.0, h + 0.9, z - 2.0), 0.0, (1.6, 1.4, 1.6)))
    acs.append(((x - 3.0, h + 0.6, z + 2.0), 0.0, (1.3, 0.9, 1.1)))
multimesh("WindowPanes", "Flats", "BoxMesh_unit", "tyre", panes, shadows=False)
multimesh("WindowBars", "Flats", "BoxMesh_unit", "rust_metal", bars, shadows=False)
multimesh("WindowLedges", "Flats", "BoxMesh_unit", "concrete_dust", ledges, shadows=False)
multimesh("WaterTanks", "Flats", "CylinderMesh_unit", "plaster_white", tanks)
multimesh("ACUnits", "Flats", "BoxMesh_unit", "corrugated", acs)
# Two alleys are the gaps left between the north blocks at x≈-29 and x≈+32.

# --- the padlocked fence -----------------------------------------------------
group("Fences")
multimesh(
    "FencePosts", "Fences", "BoxMesh_unit", "rust_metal",
    [((-44 + i * 1.9, 0.6, 7.5), 0.0, (0.12, 1.2, 0.12)) for i in range(14)],
)
multimesh(
    "FenceRails", "Fences", "BoxMesh_unit", "rust_metal",
    [((-44 + i * 1.9 + 0.95, y, 7.5), 0.0, (1.9, 0.08, 0.06)) for i in range(13) for y in (0.45, 1.05)],
    shadows=False,
)
solid("GatePost", "Fences", (-30.6, 0.7, 7.5), (0.2, 1.4, 0.2), "rust_metal")
solid("Padlock", "Fences", (-31.1, 0.95, 7.5), (0.22, 0.3, 0.12), "timber", collide=False)

# --- the bus stop ------------------------------------------------------------
group("BusStop")
# The seating model is 4.35 m of modular bench, its origin 0.2 m off centre.
BENCHES = [((9.2, 0.16, 21.0), math.pi), ((-9.8, 0, 0.0), -math.pi / 2), ((9.8, 0, 0.0), math.pi / 2)]
batch("Benches", "BusStop", "bench", [(pos, yaw, (1, 1, 1)) for pos, yaw in BENCHES])
collider("BenchBody", "BusStop", (4.4, 0.9, 0.8), [((x - 0.2 * math.cos(yaw), y + 0.45, z + 0.2 * math.sin(yaw)), yaw) for (x, y, z), yaw in BENCHES])
solid("Shelter", "BusStop", (9, 2.6, 20.8), (5.2, 0.16, 2.6), "corrugated", collide=False)
solid("ShelterPostL", "BusStop", (6.7, 1.3, 21.9), (0.16, 2.6, 0.16), "rust_metal")
solid("ShelterPostR", "BusStop", (11.3, 1.3, 21.9), (0.16, 2.6, 0.16), "rust_metal")
solid("StopSign", "BusStop", (11.9, 2.0, 21.9), (0.7, 0.9, 0.06), "road_paint", collide=False)
# Where the slice ends (§4.6): arriving with a can placed or taken, or *Sit*.
nodes.append(
    '[node name="BusStopPoint" parent="BusStop" instance=ExtResource("15_bus_stop")]\n'
    "unique_name_in_owner = true\n"
    f"transform = {xf((9.2, 0.16, 20.0))}\n\n"
)

# --- cables between the flats, trees, parked cars (§B3) -----------------------
group("Dressing")
cables = []
for i in range(5):
    # from a north flat's roofline across the road to a south flat's
    nx, nz = north[i + 1]
    sx, sz = south[i]
    x0, x1 = nx, sx
    z0, z1 = nz + 5.0, sz - 5.0
    length = math.hypot(x1 - x0, z1 - z0)
    yaw = math.atan2(x1 - x0, z1 - z0)
    cables.append((((x0 + x1) / 2, 6.6, (z0 + z1) / 2), yaw, (0.03, 0.03, length)))
    cables.append((((x0 + x1) / 2, 6.3, (z0 + z1) / 2 + 0.4), yaw, (0.03, 0.03, length)))
multimesh("Cables", "Dressing", "BoxMesh_unit", "tyre", cables, shadows=False)

# Trees (Quaternius, textured, 5-10 m tall at scale 1) in three kinds with a
# trunk collider each; bushes along the fence and under the flats.
tree_spots = [(-30, 25.5), (-6, 25.5), (24, 25.5), (50, 6.5), (-50, 6.5), (40, -8.5), (-62, 25.5), (54, 25.5), (-40, 6.8), (20, -30)]
TREE_SCALE = 0.85
for kind, picks in (("tree_3", tree_spots[0::3]), ("birch_1", tree_spots[1::3]), ("pine_2", tree_spots[2::3])):
    batch(f"Trees_{kind}", "Dressing", kind,
          [((x, 0.0, z), (x * 0.7 + z * 0.3) % 6.28, (TREE_SCALE,) * 3) for x, z in picks])
collider("TreeTrunks", "Dressing", (0.6, 4.0, 0.6), [((x, 2.0, z), 0.0) for x, z in tree_spots])
bush_spots = [(-42, 6.3), (-36, 6.3), (-26, 6.3), (-60, 25.6), (-14, 25.6), (34, 25.6), (46, 25.6), (38.5, -16), (38.5, -28)]
batch("Bushes", "Dressing", "bush",
      [((x, 0.0, z), (x * 1.3) % 6.28, (4.0, 3.6, 4.0)) for x, z in bush_spots], shadows=False)

# Parked at the kerb: Quaternius cars, and Poly Haven's car under a tarp.
PARKED = [("car_normal2", (-24, 0, 11.3), math.pi / 2), ("car_sports", (40, 0, 20.7), -math.pi / 2),
          ("car_sports2", (-12, 0, 11.4), math.pi / 2), ("car_suv", (34.2, 0, -20), 0.0)]
for i, (kind, pos, yaw) in enumerate(PARKED):
    model(f"ParkedCar{i}", "Dressing", kind, pos, yaw, CAR_SCALE)
model("CoveredCar", "Dressing", "covered_car", (52, 0, 11.3), math.pi / 2)
collider("ParkedBody", "Dressing", (2.0, 1.5, 4.3),
         [((x, 0.85, z), yaw) for _, (x, _, z), yaw in PARKED] + [((52, 0.85, 11.3), math.pi / 2)])

# Pavement furniture and litter.
batch("Hydrants", "Dressing", "hydrant", [((-20, 0.16, 8.0), 0.3, (1, 1, 1)), ((37.8, 0.16, -30), 1.8, (1, 1, 1))])
collider("HydrantBody", "Dressing", (0.5, 0.9, 0.5), [((-20, 0.6, 8.0), 0.0), ((37.8, 0.6, -30), 0.0)])
batch("Cans", "Dressing", "can",
      [((x, y, z), (x * 0.9) % 6.28, (1.4, 1.4, 1.4))
       for x, y, z in ((-33, 0.16, 8.6), (3, 0.16, 9.8), (18, 0.16, 22.4), (-10, 0, 26.2), (36.2, 0.16, -2), (-5, 0, -9.4))],
      shadows=False)

# --- lamp posts along the pavements ------------------------------------------
group("Lamps")
lamp_positions = [((x, 2.75, 8.2), 0.0, (0.16, 5.5, 0.16)) for x in range(-56, 60, 14)]
lamp_positions += [((x, 2.75, 23.8), 0.0, (0.16, 5.5, 0.16)) for x in range(-49, 60, 14)]
lamp_positions += [((22.2, 2.75, z), 0.0, (0.16, 5.5, 0.16)) for z in range(-38, 2, 14)]
# Poly Haven's street_lamp_01 is 3.9 m tall; at this scale, a street lamp.
LAMP_SCALE = 1.35
batch("LampPosts", "Lamps", "lamp", [((p[0], 0.16, p[2]), 0.0, (LAMP_SCALE,) * 3) for p, _, _ in lamp_positions])
collider("LampBody", "Lamps", (0.4, 5.2, 0.4), [((p[0], 2.6, p[2]), 0.0) for p, _, _ in lamp_positions])

# --- ambience: pedestrians and vehicles on loops (§4.1) ----------------------
group("Ambience")
# Loops kept clear of the shop (x -19..-9, z -4..3), the chai stall
# (x 10..16, z -11..-7), the fountain (±7) and the flats. Pavement y is 0.16.
PED_PATHS = [
    ([(-22, 0.16, 9), (14, 0.16, 9), (14, 0.16, 23), (-22, 0.16, 23)], 1.25),
    ([(20, 0.16, 10), (44, 0.16, 10), (44, 0.16, -6), (20, 0.16, -6)], 1.05),
    ([(-6, 0, -16), (8, 0, -16), (8, 0, -9), (-6, 0, -9)], 1.4),
    ([(-40, 0, 12), (-22, 0, 12), (-22, 0, 5), (-40, 0, 5)], 0.95),
    ([(34, 0.16, 23), (52, 0.16, 23), (52, 0.16, 24.4), (34, 0.16, 24.4)], 1.15),
]
for i, (pts, spd) in enumerate(PED_PATHS):
    pts_s = ", ".join(f"{c:g}" for p in pts for c in p)
    props = (
        f'script = ExtResource("3_pathmover")\n'
        f"points = PackedVector3Array({pts_s})\nspeed = {spd:g}\n"
        f"face_travel = true\nstart_offset = {i * 7.0:g}\n"
        f"yield_distance = 1.6\nyield_width = 0.9\n\n"
    )
    figure(f"Pedestrian{i}", "Ambience", PEDESTRIAN_SKINS[i % len(PEDESTRIAN_SKINS)], script_props=props)
    nodes.append(
        f'[node name="Body" type="StaticBody3D" parent="Ambience/Pedestrian{i}"]\n'
        f"collision_layer = 1\ncollision_mask = 0\n\n"
        f'[node name="Shape" type="CollisionShape3D" parent="Ambience/Pedestrian{i}/Body"]\n'
        f"transform = {xf((0, 0.9, 0))}\n"
        f'shape = SubResource("CapsuleShape3D_ped")\n\n'
    )

VEH_PATHS = [
    ([(-60, 0, 17.5), (60, 0, 17.5)], 7.5, "car_taxi"),
    ([(60, 0, 14.5), (-60, 0, 14.5)], 6.2, "car_normal1"),
    ([(30, 0, -40), (30, 0, 44)], 8.0, "car_suv"),
]
for i, (pts, spd, kind) in enumerate(VEH_PATHS):
    pts_s = ", ".join(f"{c:g}" for p in pts for c in p)
    nodes.append(
        f'[node name="Vehicle{i}" type="Node3D" parent="Ambience"]\n'
        f'script = ExtResource("3_pathmover")\n'
        f"points = PackedVector3Array({pts_s})\nspeed = {spd:g}\n"
        f"face_travel = true\nstart_offset = {i * 31.0:g}\n"
        f"yield_distance = 9.0\nyield_width = 2.2\n\n"
    )
    v = f"Ambience/Vehicle{i}"
    model("Model", v, kind, (0, 0, 0), math.pi, CAR_SCALE)
    collider("Body", v, (2.0, 1.5, 4.3), [((0, 0.75, 0), 0.0)])

# ================================================================ assembly

header = (
    "[gd_scene load_steps=STEPS format=3]\n\n"
    "; Hollow Vale — the Street. GENERATED by tools/gen_street.py; edit that, not\n"
    "; this. CLAUDE_CODE_BRIEF.md §4.1 with the owner's 2026-10-19 decision to\n"
    "; texture the slice (docs/DECISIONS.md).\n;\n"
    "; PLACEHOLDER: primitives with procedural textures, and CC0 stand-in models\n"
    "; (Kenney, Poly Haven; docs/RIGHTS_REGISTER.md). Replaced by the painted\n"
    "; stylized 3D of GDD §10.\n;\n"
    "; Palette: GDD §10, Hollow Vale row. Peacock blue and magenta are forbidden\n"
    "; here; the only exception in the slice is the Glimpse and its feather (P5).\n\n"
    '[ext_resource type="Script" path="res://scripts/street/street.gd" id="1_street"]\n'
    '[ext_resource type="Script" path="res://scripts/street/climb_point.gd" id="2_climb"]\n'
    '[ext_resource type="Script" path="res://scripts/street/path_mover.gd" id="3_pathmover"]\n'
    '[ext_resource type="PackedScene" path="res://scenes/player/Player.tscn" id="4_player"]\n'
    '[ext_resource type="PackedScene" path="res://scenes/player/CameraRig.tscn" id="5_rig"]\n'
    '[ext_resource type="PackedScene" path="res://scenes/ui/TouchControls.tscn" id="6_controls"]\n'
    '[ext_resource type="PackedScene" path="res://scenes/characters/Character.tscn" id="8_character"]\n'
    + "".join(
        f'[ext_resource type="Texture2D" path="res://assets/thirdparty/kenney/{path}" id="skin_{skin}"]\n'
        for skin, path in SKIN_PATH.items()
    )
    + '[ext_resource type="Texture2D" path="res://assets/thirdparty/polyhaven/overcast_soil_puresky.hdr" id="8_sky"]\n'
    '[ext_resource type="PackedScene" path="res://scenes/npc/Tulu.tscn" id="9_tulu"]\n'
    '[ext_resource type="Script" path="res://scripts/street/model_batch.gd" id="batch"]\n'
    '[ext_resource type="Script" path="res://scripts/lib/interactable.gd" id="2_interact"]\n'
    '[ext_resource type="Script" path="res://scripts/quest/can_stack.gd" id="11_can_stack"]\n'
    '[ext_resource type="PackedScene" path="res://scenes/npc/Gopal.tscn" id="12_gopal"]\n'
    '[ext_resource type="PackedScene" path="res://scenes/quest/FountainPoint.tscn" id="13_fountain_point"]\n'
    '[ext_resource type="PackedScene" path="res://scenes/quest/Glimpse.tscn" id="14_glimpse"]\n'
    '[ext_resource type="PackedScene" path="res://scenes/quest/BusStopPoint.tscn" id="15_bus_stop"]\n'
    + "".join(
        f'[ext_resource type="PackedScene" path="res://assets/thirdparty/{path}" id="{MODEL_ID[m]}"]\n'
        for m, path in MODELS.items()
    )
    + "".join(
        f'[ext_resource type="Material" path="res://assets/materials/{m}.tres" id="{MAT_ID[m]}"]\n'
        for m in MATS
    )
    + """
[sub_resource type="BoxMesh" id="BoxMesh_unit"]
size = Vector3(1, 1, 1)

[sub_resource type="CylinderMesh" id="CylinderMesh_unit"]
top_radius = 0.5
bottom_radius = 0.5
height = 1.0
radial_segments = 12
rings = 0

[sub_resource type="CylinderMesh" id="ConeMesh_unit"]
top_radius = 0.5
bottom_radius = 0.12
height = 1.0
radial_segments = 16
rings = 0

[sub_resource type="TorusMesh" id="TorusMesh_lip"]
inner_radius = 5.6
outer_radius = 7.0
rings = 48
ring_segments = 10

[sub_resource type="CylinderShape3D" id="CylinderShape3D_basin"]
radius = 7.0
height = 0.75

[sub_resource type="BoxShape3D" id="BoxShape3D_cans"]
size = Vector3(9.5, 2.0, 3.6)

[sub_resource type="BoxShape3D" id="BoxShape3D_climb"]
size = Vector3(7, 1.8, 2.4)

[sub_resource type="CapsuleShape3D" id="CapsuleShape3D_ped"]
radius = 0.3
height = 1.8

[sub_resource type="PanoramaSkyMaterial" id="Sky_overcast"]
panorama = ExtResource("8_sky")
filter = true
energy_multiplier = 1.0

[sub_resource type="Sky" id="Sky_flat"]
sky_material = SubResource("Sky_overcast")
radiance_size = 2

[sub_resource type="SphereMesh" id="SphereMesh_unit"]
radius = 0.5
height = 1.0
radial_segments = 12
rings = 6

[sub_resource type="Environment" id="Environment_vale"]
background_mode = 2
sky = SubResource("Sky_flat")
ambient_light_source = 1
ambient_light_color = Color(0.64, 0.66, 0.7, 1)
ambient_light_sky_contribution = 0.45
ambient_light_energy = 1.3
reflected_light_source = 2
tonemap_mode = 2
tonemap_exposure = 1.0
fog_enabled = true
fog_light_color = Color(0.86, 0.83, 0.77, 1)
fog_density = 0.0014
fog_sky_affect = 0.3

"""
)

root = """[node name="Street" type="Node3D"]
script = ExtResource("1_street")

[node name="Environment" type="WorldEnvironment" parent="."]
environment = SubResource("Environment_vale")

; Overcast, but with a sun low enough to throw soft shadows: depth reads far
; better once surfaces have texture. Orthogonal shadow, 45 m, one cascade.
[node name="Sun" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.866, -0.35, 0.357, 0, 0.714, 0.7, -0.5, -0.606, 0.618, 0, 24, 0)
light_energy = 0.95
light_color = Color(1, 0.98, 0.94, 1)
light_bake_mode = 2
shadow_enabled = SHADOW_STANDIN
shadow_opacity = 0.65
shadow_bias = 0.06
shadow_normal_bias = 1.5
directional_shadow_mode = 0
directional_shadow_max_distance = 45.0
directional_shadow_fade_start = 0.85

; §B5: baked lighting. Baking needs the editor and a GPU (there is no headless
; bake in Godot 4.3): select this node, press Bake Lightmaps, commit the
; .lmbake it writes, and set REALTIME_SHADOW_STANDIN = False in the generator.
[node name="Lightmap" type="LightmapGI" parent="."]
quality = 1
bounces = 2
directional = false
use_denoiser = true
environment_mode = 1

"""

footer = f"""; The player surfaces beside the column, not behind it: due north from here
; is clear floor up to the lip and the climb out.
[node name="Player" parent="." instance=ExtResource("4_player")]
unique_name_in_owner = true
transform = {xf((2.4, -0.4, 2.0))}

[node name="CameraRig" parent="." instance=ExtResource("5_rig")]
unique_name_in_owner = true
target_path = NodePath("../Player")

; Walking into the north wall from inside the basin climbs the player out.
; No button: GDD §6, "approach a ledge or ladder and the character climbs".
[node name="ClimbOut" type="Area3D" parent="."]
transform = {xf((0, 0.0, -5.5))}
collision_layer = 0
collision_mask = 2
monitorable = false
script = ExtResource("2_climb")
exit_marker_path = NodePath("../ClimbOutExit")

[node name="Shape" type="CollisionShape3D" parent="ClimbOut"]
shape = SubResource("BoxShape3D_climb")

[node name="ClimbOutExit" type="Marker3D" parent="."]
transform = {xf((0, 0.05, -8.8))}

; Tulu waits at the fountain's edge where the player surfaces, then leads to
; the chai stall's back door (CLAUDE_CODE_BRIEF.md §4.3). Waypoints are the
; pavement route round the stall, not a straight line through it.
[node name="Tulu" parent="." instance=ExtResource("9_tulu")]
unique_name_in_owner = true
transform = Transform3D(0.72, 0, 0, 0, 0.72, 0, 0, 0, 0.72, 3.2, 0.05, -9.4)
waypoints = PackedVector3Array(6, 0.05, -11, 10, 0.05, -14.5, 15.5, 0.05, -14.5, 15.0, 0.05, -12.4)

[node name="UI" type="CanvasLayer" parent="."]

[node name="TouchControls" parent="UI" instance=ExtResource("6_controls")]
unique_name_in_owner = true
"""


def render() -> str:
    shape_defs = "".join(
        f'[sub_resource type="BoxShape3D" id="{sid}"]\nsize = Vector3({k[0]:g}, {k[1]:g}, {k[2]:g})\n\n'
        for k, sid in shapes.items()
    )
    body = header + shape_defs + "".join(multimeshes) + root + "".join(nodes) + footer
    body = body.replace("SHADOW_STANDIN", "true" if REALTIME_SHADOW_STANDIN else "false")
    steps = body.count("[ext_resource ") + body.count("[sub_resource ") + 1
    return body.replace("load_steps=STEPS", f"load_steps={steps}", 1)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    text = render()
    if args.check:
        if not OUT.exists() or OUT.read_text() != text:
            print("gen_street: scenes/street/Street.tscn is stale; run tools/gen_street.py", file=sys.stderr)
            return 1
        print("gen_street: Street.tscn is current")
        return 0
    OUT.write_text(text)
    print(f"gen_street: wrote {OUT.relative_to(ROOT)}: {len(nodes)} node blocks, "
          f"{len(multimeshes)} multimeshes, {len(shapes)} shapes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
