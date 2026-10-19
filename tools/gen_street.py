#!/usr/bin/env python3
"""Generate scenes/street/Street.tscn — Hollow Vale's one block.

The street is a few hundred primitives placed by rules, and the rules are
easier to read and change here than as a 1,500-line scene file. Run this after
editing it; the .tscn it writes is an ordinary Godot scene and is committed.

    python3 tools/gen_street.py           # writes scenes/street/Street.tscn
    python3 tools/gen_street.py --check   # fails if the committed scene is stale

Layout: X east, Z south, Y up. The fountain is at the origin; the ground is
four slabs whose gap is exactly the fountain's footprint. Repeated props (lamp
posts, road dashes, window bars, fence rails, rooftop tanks, cables, trees) are
MultiMeshes: one draw call each, however many there are. Budget (amendment
§C): under 200 draw calls and 150k triangles per frame.
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


def figure(name, parent, mat, pos=(0, 0, 0), script_props="", scale=1.0) -> None:
    """A low-poly humanoid with the procedural walk (§B4). Pedestrians use it;
    the player's is hand-built in Player.tscn to the same proportions."""
    root = f"{parent}/{name}"
    body = f"{root}/Figure"
    nodes.append(
        f'[node name="{name}" type="Node3D" parent="{parent}"]\n'
        f"transform = {xf(pos, 0.0, (scale, scale, scale))}\n{script_props}\n"
        f'[node name="Figure" type="Node3D" parent="{root}"]\n'
        f'script = ExtResource("7_animator")\n\n'
        f'[node name="Torso" type="Node3D" parent="{body}"]\n\n'
    )
    def part(nm, parent_path, pos_, size, m, mesh="BoxMesh_unit"):
        nodes.append(
            f'[node name="{nm}" type="MeshInstance3D" parent="{parent_path}"]\n'
            f"transform = {xf(pos_, 0.0, size)}\n"
            f'mesh = SubResource("{mesh}")\n'
            f'surface_material_override/0 = ExtResource("{MAT_ID[m]}")\n\n'
        )
    torso = f"{body}/Torso"
    part("Chest", torso, (0, 1.2, 0), (0.44, 0.6, 0.25), mat)
    part("Hips", torso, (0, 0.8, 0), (0.38, 0.22, 0.25), "tyre")
    part("Head", torso, (0, 1.7, 0), (0.33, 0.35, 0.33), "skin", "SphereMesh_unit")
    part("Hair", torso, (0, 1.8, 0.02), (0.36, 0.2, 0.36), "timber", "SphereMesh_unit")
    for side, sx in (("LeftArm", 0.29), ("RightArm", -0.29)):
        nodes.append(f'[node name="{side}" type="Node3D" parent="{body}"]\ntransform = {xf((sx, 1.45, 0))}\n\n')
        part("Upper", f"{body}/{side}", (0, -0.3, 0), (0.11, 0.58, 0.11), mat)
    for side, sx in (("LeftLeg", 0.11), ("RightLeg", -0.11)):
        nodes.append(f'[node name="{side}" type="Node3D" parent="{body}"]\ntransform = {xf((sx, 0.7, 0))}\n\n')
        part("Thigh", f"{body}/{side}", (0, -0.35, 0), (0.15, 0.68, 0.17), "tyre")
        part("Foot", f"{body}/{side}", (0, -0.68, -0.05), (0.16, 0.08, 0.26), "timber")


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

# --- the dry fountain --------------------------------------------------------
group("Fountain")
solid("Floor", "Fountain", (0, -1.25, 0), (14, 0.3, 14), "concrete_dust")
solid("WallNorth", "Fountain", (0, -0.2, -6.65), (14, 1.8, 0.7), "ph_concrete")
solid("WallSouth", "Fountain", (0, -0.2, 6.65), (14, 1.8, 0.7), "ph_concrete")
solid("WallWest", "Fountain", (-6.65, -0.2, 0), (0.7, 1.8, 12.6), "ph_concrete")
solid("WallEast", "Fountain", (6.65, -0.2, 0), (0.7, 1.8, 12.6), "ph_concrete")
# A coping stone along the rim.
for z in (-6.65, 6.65):
    solid(f"Coping{z:g}", "Fountain", (0, 0.76, z), (14.3, 0.12, 1.0), "concrete_dust", collide=False)
for x in (-6.65, 6.65):
    solid(f"CopingX{x:g}", "Fountain", (x, 0.76, 0), (1.0, 0.12, 14.3), "concrete_dust", collide=False)
cyl("Spout", "Fountain", (0, -0.55, 0), 0.45, 1.1, "plaster_white")
cyl("SpoutBase", "Fountain", (0, -1.05, 0), 1.1, 0.14, "concrete_dust")

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
# Water cans, stacked where the street can see them (§4.4).
for i in range(12):
    col, row = i % 4, i // 4
    cyl(f"Can{i}", "Shop", (-17.2 + col * 2.1, 0.35, -2.6 + row * 1.1), 0.33, 0.7, "rust_metal")

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
solid("Bench", "BusStop", (9, 0.45, 20.5), (3.4, 0.18, 0.7), "timber")
solid("BenchBack", "BusStop", (9, 0.85, 20.85), (3.4, 0.5, 0.08), "timber", collide=False)
solid("BenchLegL", "BusStop", (7.6, 0.22, 20.5), (0.16, 0.45, 0.6), "rust_metal", collide=False)
solid("BenchLegR", "BusStop", (10.4, 0.22, 20.5), (0.16, 0.45, 0.6), "rust_metal", collide=False)
solid("Shelter", "BusStop", (9, 2.6, 20.8), (4.4, 0.16, 2.4), "corrugated", collide=False)
solid("ShelterPostL", "BusStop", (7.1, 1.3, 21.7), (0.16, 2.6, 0.16), "rust_metal")
solid("ShelterPostR", "BusStop", (10.9, 1.3, 21.7), (0.16, 2.6, 0.16), "rust_metal")
solid("StopSign", "BusStop", (11.6, 2.0, 21.9), (0.7, 0.9, 0.06), "road_paint", collide=False)

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

tree_spots = [(-30, 0.1, 25.5), (-6, 0.1, 25.5), (24, 0.1, 25.5), (50, 0.1, 6.5), (-50, 0.1, 6.5), (40, 0.1, -8.5)]
multimesh("Trunks", "Dressing", "CylinderMesh_unit", "timber",
          [((x, y + 1.6, z), 0.0, (0.3, 3.2, 0.3)) for x, y, z in tree_spots])
multimesh("Canopies", "Dressing", "SphereMesh_unit", "canopy",
          [((x, y + 4.2, z), 0.0, (3.4, 2.6, 3.4)) for x, y, z in tree_spots])
multimesh("CanopiesTop", "Dressing", "SphereMesh_unit", "canopy",
          [((x + 0.6, y + 5.2, z - 0.4), 0.0, (2.2, 1.8, 2.2)) for x, y, z in tree_spots])

for i, (px, pz, yaw, body) in enumerate(((-24, 11.2, 0.0, "plaster_cream"), (40, 20.8, math.pi, "rust_metal"))):
    group(f"ParkedCar{i}", "Dressing")
    v = f"Dressing/ParkedCar{i}"
    nodes[-1] = f'[node name="ParkedCar{i}" type="Node3D" parent="Dressing"]\ntransform = {xf((px, 0, pz), yaw)}\n\n'
    solid("Body", v, (0, 0.75, 0), (1.9, 0.9, 4.2), body)
    solid("Cabin", v, (0, 1.45, -0.3), (1.7, 0.6, 2.2), "tyre", collide=False)
    for j, (dx, dz) in enumerate(((-0.95, 1.3), (0.95, 1.3), (-0.95, -1.3), (0.95, -1.3))):
        cyl(f"Wheel{j}", v, (dx, 0.34, dz), 0.34, 0.26, "tyre", lay=True)

# --- lamp posts along the pavements ------------------------------------------
group("Lamps")
lamp_positions = [((x, 2.75, 8.2), 0.0, (0.16, 5.5, 0.16)) for x in range(-56, 60, 14)]
lamp_positions += [((x, 2.75, 23.8), 0.0, (0.16, 5.5, 0.16)) for x in range(-49, 60, 14)]
lamp_positions += [((22.2, 2.75, z), 0.0, (0.16, 5.5, 0.16)) for z in range(-38, 2, 14)]
multimesh("LampPosts", "Lamps", "CylinderMesh_unit", "rust_metal", lamp_positions)
multimesh(
    "LampHeads", "Lamps", "BoxMesh_unit", "road_paint",
    [((p[0], 5.55, p[2]), 0.0, (0.7, 0.22, 0.4)) for p, _, _ in lamp_positions], shadows=False,
)

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
    figure(f"Pedestrian{i}", "Ambience", "cloth_pale" if i % 2 else "coat", script_props=props)
    nodes.append(
        f'[node name="Body" type="StaticBody3D" parent="Ambience/Pedestrian{i}"]\n'
        f"collision_layer = 1\ncollision_mask = 0\n\n"
        f'[node name="Shape" type="CollisionShape3D" parent="Ambience/Pedestrian{i}/Body"]\n'
        f"transform = {xf((0, 0.9, 0))}\n"
        f'shape = SubResource("CapsuleShape3D_ped")\n\n'
    )

VEH_PATHS = [
    ([(-60, 0, 17.5), (60, 0, 17.5)], 7.5, "plaster_white"),
    ([(60, 0, 14.5), (-60, 0, 14.5)], 6.2, "rust_metal"),
    ([(30, 0, -40), (30, 0, 44)], 8.0, "plaster_cream"),
]
for i, (pts, spd, body) in enumerate(VEH_PATHS):
    pts_s = ", ".join(f"{c:g}" for p in pts for c in p)
    nodes.append(
        f'[node name="Vehicle{i}" type="Node3D" parent="Ambience"]\n'
        f'script = ExtResource("3_pathmover")\n'
        f"points = PackedVector3Array({pts_s})\nspeed = {spd:g}\n"
        f"face_travel = true\nstart_offset = {i * 31.0:g}\n"
        f"yield_distance = 9.0\nyield_width = 2.2\n\n"
    )
    v = f"Ambience/Vehicle{i}"
    solid("Body", v, (0, 0.75, 0), (1.9, 0.9, 4.2), body, collide=True)
    solid("Cabin", v, (0, 1.45, -0.3), (1.7, 0.6, 2.2), "tyre", collide=False)
    for j, (dx, dz) in enumerate(((-0.95, 1.3), (0.95, 1.3), (-0.95, -1.3), (0.95, -1.3))):
        cyl(f"Wheel{j}", v, (dx, 0.34, dz), 0.34, 0.26, "tyre", lay=True)

# ================================================================ assembly

header = (
    "[gd_scene load_steps=STEPS format=3]\n\n"
    "; Hollow Vale — the Street. GENERATED by tools/gen_street.py; edit that, not\n"
    "; this. CLAUDE_CODE_BRIEF.md §4.1 with the owner's 2026-10-19 decision to\n"
    "; texture the slice (docs/DECISIONS.md).\n;\n"
    "; PLACEHOLDER: every mesh is a primitive with a procedural texture.\n"
    "; Replaced by the painted stylized 3D of GDD §10.\n;\n"
    "; Palette: GDD §10, Hollow Vale row. Peacock blue and magenta are forbidden\n"
    "; here; the only exception in the slice is the Glimpse and its feather (P5).\n\n"
    '[ext_resource type="Script" path="res://scripts/street/street.gd" id="1_street"]\n'
    '[ext_resource type="Script" path="res://scripts/street/climb_point.gd" id="2_climb"]\n'
    '[ext_resource type="Script" path="res://scripts/street/path_mover.gd" id="3_pathmover"]\n'
    '[ext_resource type="PackedScene" path="res://scenes/player/Player.tscn" id="4_player"]\n'
    '[ext_resource type="PackedScene" path="res://scenes/player/CameraRig.tscn" id="5_rig"]\n'
    '[ext_resource type="PackedScene" path="res://scenes/ui/TouchControls.tscn" id="6_controls"]\n'
    '[ext_resource type="Script" path="res://scripts/player/figure_animator.gd" id="7_animator"]\n'
    '[ext_resource type="Texture2D" path="res://assets/thirdparty/polyhaven/overcast_soil_puresky.hdr" id="8_sky"]\n'
    '[ext_resource type="PackedScene" path="res://scenes/npc/Tulu.tscn" id="9_tulu"]\n'
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

[sub_resource type="BoxShape3D" id="BoxShape3D_climb"]
size = Vector3(7, 1.8, 2.2)

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
ambient_light_source = 2
ambient_light_sky_contribution = 1.0
ambient_light_energy = 0.85
reflected_light_source = 2
tonemap_mode = 2
tonemap_exposure = 1.05
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
; better once surfaces have texture. Orthogonal shadow, 70 m, one cascade.
[node name="Sun" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.866, -0.35, 0.357, 0, 0.714, 0.7, -0.5, -0.606, 0.618, 0, 24, 0)
light_energy = 1.15
light_color = Color(1, 0.98, 0.94, 1)
light_bake_mode = 2
shadow_enabled = SHADOW_STANDIN
shadow_bias = 0.06
shadow_normal_bias = 1.5
directional_shadow_mode = 0
directional_shadow_max_distance = 70.0
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

footer = f"""[node name="Player" parent="." instance=ExtResource("4_player")]
unique_name_in_owner = true
transform = {xf((0, -1.0, 2.0))}

[node name="CameraRig" parent="." instance=ExtResource("5_rig")]
unique_name_in_owner = true
target_path = NodePath("../Player")

; Walking into the north wall from inside the basin climbs the player out.
; No button: GDD §6, "approach a ledge or ladder and the character climbs".
[node name="ClimbOut" type="Area3D" parent="."]
transform = {xf((0, -0.35, -5.2))}
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
