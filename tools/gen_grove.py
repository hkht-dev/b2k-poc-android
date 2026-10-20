#!/usr/bin/env python3
"""Generate scenes/places/Grove.tscn — the Grove riverbank, Act 1.

GDD §3 Act 1, §3a Act 1 table, §5 "The Grove riverbank" (≈80 × 60 m: a river
with an unreachable far bank, the feast clearing, the calf meadow, the flower
garden, the kadamba tree with a swing, the tree Krishna leans on across the
water, the Pool at the Grove's edge, drifting bubbles; eternal rose-gold
dusk, a sky with visible stars). Built the way the street and the shop
insides are: primitives and CC0 models through tools/scenegen.py, the same
player, camera and HUD, the Place base script with place_id "grove".

    python3 tools/gen_grove.py           # writes scenes/places/Grove.tscn
    python3 tools/gen_grove.py --check   # fails if the committed scene is stale

Layout: X east, Z south, Y up. The meadow is centred on the origin, its top
at y = 0; the river runs east-west along the north edge (z −30 to −42) with
the far bank beyond it; the Pool is at the east edge. The playable 80 × 60 m
is fenced by invisible walls, so the river cannot be crossed (GDD §3: "The
player can approach the water but cannot cross").

Palette: GDD §10 Grove row, rose-gold dusk, as far as this slice allows it:
peacock blue and magenta are kept out of the Grove too (CLAUDE.md; the
feather is the Street's one exception and does not appear here), so the sky
is rose and amber rather than magenta. tests/test_grove.gd checks every
albedo, light and sky colour against that.
"""

from __future__ import annotations

import argparse
import math
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "scenes" / "places" / "Grove.tscn"

sys.path.insert(0, str(Path(__file__).resolve().parent))
from scenegen import (  # noqa: E402
    COMMON_EXT, MAT_ID, MESHES, Builder, ext_materials, ext_models, ext_skins, finish, xf,
)

# The Grove's own materials, beside the street's (assets/materials/*.tres).
# Grass is the street's since the world assets landed (scenegen MATERIALS);
# naming it here too wrote its ext_resource twice.
GROVE_MATS = {"pool": "mat_pool", "petal": "mat_petal", "star": "mat_star", "water": "mat_water"}
MAT_ID.update(GROVE_MATS)

NORTH = 0.0
SOUTH = math.pi
EAST = -math.pi / 2
WEST = math.pi / 2

# The playable meadow and the river beyond its north edge.
HALF_W, HALF_D = 40.0, 30.0
RIVER_NEAR, RIVER_FAR = -HALF_D, -42.0
WATER_Y = -0.26
# Where things are. Changing a number here moves the thing and its colliders.
WAKE = (-3.0, 0.0, -24.0)
FEAST = (-14.0, 0.0, 6.0)
LALITA = (-14.0, 0.0, 9.4)
POT_PLACE = (-11.4, 0.0, 8.6)
POT_PICKUP = (2.0, 0.0, -28.4)
KUVERA = (13.0, 0.0, -26.0)
MEADOW = (8.0, 0.0, 17.0)
GARDEN = (-24.0, 0.0, -12.0)
GARDEN_SIZE = (14.0, 10.0)
KADAMBA = (20.0, 0.0, -5.0)
POOL = (31.0, 0.0, 17.0)
POOL_R = 6.0
FAR_TREE = (9.0, 0.0, -49.0)
FAR_FIGURE = (7.4, 0.0, -47.6)
# The sun: low in the north-north-east, behind the figure across the water
# ("the sun low and pink behind", GDD §3). This is the direction its light
# travels: down, south and a little west.
SUN_DIRECTION = (-0.3, -0.18, 0.93)
STAR_COUNT = 240
STAR_DOME = 140.0  # inside the camera's 160 m far plane (CameraRig.tscn)

rng = random.Random(108)
b = Builder()


# ----------------------------------------------------------------- helpers

def _norm(v):
    length = math.sqrt(sum(c * c for c in v)) or 1.0
    return tuple(c / length for c in v)


def _cross(a, c):
    return (a[1] * c[2] - a[2] * c[1], a[2] * c[0] - a[0] * c[2], a[0] * c[1] - a[1] * c[0])


def basis_xf(bx, by, bz, pos) -> str:
    """A Transform3D from three basis columns and an origin."""
    v = [*bx, *by, *bz, *pos]
    return "Transform3D(" + ", ".join(f"{n:g}" for n in v) + ")"


def look_xf(direction, pos) -> str:
    """A transform whose −Z points along `direction`: a light's."""
    bz = tuple(-c for c in _norm(direction))
    bx = _norm(_cross((0.0, 1.0, 0.0), bz))
    by = _cross(bz, bx)
    return basis_xf(bx, by, bz, pos)


def tilted_quad(yaw, pitch, size):
    """Basis columns of a PlaneMesh (lying in XZ, normal +Y) turned by yaw
    about Y and tilted by pitch about X, scaled to `size`."""
    cy, sy = math.cos(yaw), math.sin(yaw)
    cp, sp = math.cos(pitch), math.sin(pitch)
    bx = (cy * size, 0.0, -sy * size)
    by = (sy * sp * size, cp * size, cy * sp * size)
    bz = (sy * cp * size, -sp * size, cy * cp * size)
    return bx, by, bz


def facing_quad(direction, size):
    """Basis columns of a PlaneMesh whose plane is perpendicular to
    `direction`: a star on a dome, face-on to the Grove."""
    by = _norm(direction)
    helper = (0.0, 1.0, 0.0) if abs(by[1]) < 0.9 else (1.0, 0.0, 0.0)
    bx = _norm(_cross(by, helper))
    bz = _cross(bx, by)
    return tuple(c * size for c in bx), tuple(c * size for c in by), tuple(c * size for c in bz)


def colour_multimesh(name, parent, mesh_id, mat, instances) -> None:
    """One draw call for every instance, each with its own colour: Godot's
    MultiMesh buffer with use_colors is 12 floats of transform then RGBA.
    Each instance is ((bx, by, bz), pos, (r, g, b, a))."""
    floats = []
    for (bx, by, bz), pos, col in instances:
        floats += [bx[0], by[0], bz[0], pos[0], bx[1], by[1], bz[1], pos[1], bx[2], by[2], bz[2], pos[2]]
        floats += list(col)
    mm_id = f"MultiMesh_{name}"
    b.multimeshes.append(
        f'[sub_resource type="MultiMesh" id="{mm_id}"]\n'
        "transform_format = 1\nuse_colors = true\n"
        f'mesh = SubResource("{mesh_id}")\n'
        f"instance_count = {len(instances)}\n"
        f"buffer = PackedFloat32Array({', '.join(f'{f:g}' for f in floats)})\n\n"
    )
    b.nodes.append(
        f'[node name="{name}" type="MultiMeshInstance3D" parent="{parent}"]\n'
        f'multimesh = SubResource("{mm_id}")\n'
        f'material_override = ExtResource("{MAT_ID[mat]}")\n'
        "cast_shadow = 0\n\n"
    )


def keeper(name, parent, skin, lines, pos, yaw) -> None:
    """Someone with lines: scenes/npc/Shopkeeper.tscn, as the shop insides
    use it. *Talk* opens the first of `lines` whose requirements hold."""
    quoted = ", ".join(f'"{line}"' for line in lines)
    b.nodes.append(
        f'[node name="{name}" parent="{parent}" instance=ExtResource("keeper")]\n'
        "unique_name_in_owner = true\n"
        f"transform = {xf(pos, yaw)}\n"
        f"entry_lines = PackedStringArray({quoted})\n\n"
        f'[node name="Figure" parent="{parent}/{name}" index="1"]\n'
        f'skin = ExtResource("skin_{skin}")\n\n'
    )


def shrubs(name, parent, spots, size) -> None:
    """Shrubs as one MultiMesh of squashed spheres in the meadow's own green,
    three to a clump. PLACEHOLDER for the Grove's foliage of GDD §10 "Asset
    sourcing plan"; Kenney's bush is not used here because its aqua albedo
    sits in the band the Grove keeps clear of (tests/test_grove.gd)."""
    clumps = []
    for x, z in spots:
        for k in range(3):
            angle = k * 2.1 + x * 0.3
            s = size * rng.uniform(0.7, 1.0)
            pos = (x + math.sin(angle) * size * 0.35, s * 0.3, z + math.cos(angle) * size * 0.35)
            clumps.append((pos, rng.uniform(0, 6.28), (s, s * 0.7, s)))
    b.multimesh(name, parent, "SphereMesh_unit", "grass", clumps)
    b.collider(f"{name}Body", parent, (size * 0.9, 1.2, size * 0.9), [((x, 0.6, z), 0.0) for x, z in spots])


def tree_batch(name, parent, kind, spots, scale, collide=True) -> None:
    b.batch(name, parent, kind, [((x, 0.0, z), (x * 0.7 + z * 0.3) % 6.28, (scale,) * 3) for x, z in spots])
    if collide:
        b.collider(f"{name}Trunks", parent, (0.7, 4.0, 0.7), [((x, 2.0, z), 0.0) for x, z in spots])


# ================================================================ the Grove

# --- the meadow, the river, the far bank -------------------------------------
b.group("Ground")
b.solid("Meadow", "Ground", (0, -0.5, 0), (HALF_W * 2 + 10, 1, HALF_D * 2), "grass")
# Invisible walls round the playable 80 × 60 m; the river's is the one that
# matters (GDD §3: "cannot cross"), the others keep the Grove the Grove.
b.collider("BoundsEastWest", "Ground", (0.5, 4, HALF_D * 2 + 1), [((-HALF_W - 0.25, 2, 0), 0.0), ((HALF_W + 0.25, 2, 0), 0.0)])
b.collider("BoundsSouth", "Ground", (HALF_W * 2 + 1, 4, 0.5), [((0, 2, HALF_D + 0.25), 0.0)])

b.group("River")
RIVER_W = RIVER_NEAR - RIVER_FAR
RIVER_Z = (RIVER_NEAR + RIVER_FAR) / 2
b.solid("Bed", "River", (0, -1.1, RIVER_Z), (HALF_W * 2 + 10, 1, RIVER_W), "plaster_ochre")
# PLACEHOLDER water: the fountain's grey-green plane (assets/materials/
# water.tres) under a rose sky; replaced by the "river reflecting pink" of
# GDD §10 when the painted water arrives.
b.detail("Water", "River", (0, WATER_Y, RIVER_Z), (HALF_W * 2 + 10, 0.02, RIVER_W), "water")
b.collider("RiverWall", "River", (HALF_W * 2 + 1, 4, 0.5), [((0, 2, RIVER_NEAR - 0.25), 0.0)])
# A few stones along the near bank, where the pot is filled.
b.multimesh(
    "BankStones", "River", "SphereMesh_unit", "plaster_cream",
    [((x, -0.05, RIVER_NEAR + 0.3 + rng.uniform(0.0, 0.5)), rng.uniform(0, 6.28), (s, s * 0.5, s * 0.8))
     for x in range(-38, 39, 3) for s in (rng.uniform(0.5, 1.1),)],
    shadows=False,
)
# The pot, waiting at the water's edge (scripts/quest/pickup_item.gd, as the
# feather uses it): *Pick up* while the hands are empty, once per journey.
b.nodes.append(
    '[node name="PotPickup" type="Node3D" parent="River"]\n'
    "unique_name_in_owner = true\n"
    f"transform = {xf(POT_PICKUP)}\n"
    'script = ExtResource("pickup")\n'
    'item = "pot"\nevent = "pot_picked_up"\n\n'
    '[node name="PickUp" type="Area3D" parent="River/PotPickup"]\n'
    "unique_name_in_owner = true\n"
    'script = ExtResource("2_interact")\n'
    'verb_id = "verb.pick_up"\n\n'
    '[node name="Shape" type="CollisionShape3D" parent="River/PotPickup/PickUp"]\n'
    f"transform = {xf((0, 1.0, 0))}\n"
    'shape = SubResource("CylinderShape3D_near")\n\n'
    '[node name="Pot" parent="River/PotPickup" instance=ExtResource("pot")]\n'
    f"transform = {xf((0, 0.45, 0))}\n\n"
)
# Kuvera by the bank, looking across the water (GDD §4, §8 Scene A). His
# lines are data: the whisper, the variant once the water was carried, and
# what he says after.
keeper("Kuvera", "River", "criminalMaleA", ["kuvera_after", "kuvera_whisper_water", "kuvera_whisper"], KUVERA, NORTH)

b.group("FarBank")
b.solid("Bank", "FarBank", (0, -0.5, RIVER_FAR - 12), (HALF_W * 2 + 10, 1, 24), "grass")
# The tree He leans on, and the figure by it: dark against the low sun,
# flute in hand, unreachable (scripts/grove/far_figure.gd).
b.model("KrishnaTree", "FarBank", "tree_3", FAR_TREE, 0.6, 1.3)
b.nodes.append(
    '[node name="FarFigure" type="Node3D" parent="FarBank"]\n'
    "unique_name_in_owner = true\n"
    f"transform = {xf(FAR_FIGURE, SOUTH)}\n"
    'script = ExtResource("far_figure")\n'
    'paint = ExtResource("mat_far_figure")\n\n'
    '[node name="Figure" parent="FarBank/FarFigure" instance=ExtResource("8_character")]\n'
    "height = 1.85\n\n"
    # Warm, behind him: the backlight of GDD §10 "A Glimpse silhouette is
    # always backlit by a warm source".
    '[node name="Backlight" type="OmniLight3D" parent="FarBank/FarFigure"]\n'
    f"transform = {xf((0.3, 1.8, 2.2))}\n"
    "light_color = Color(1, 0.72, 0.42, 1)\nlight_energy = 3.0\nomni_range = 9.0\nshadow_enabled = false\n\n"
)
far_spots = [(x, RIVER_FAR - 8 - (x * 0.37) % 7) for x in range(-40, 41, 8) if abs(x - FAR_TREE[0]) > 5]
tree_batch("FarTrees_tree_1", "FarBank", "tree_1", far_spots[0::2], 1.15, collide=False)
tree_batch("FarTrees_birch_4", "FarBank", "birch_4", far_spots[1::2], 1.1, collide=False)

# --- the feast clearing -------------------------------------------------------
b.group("Feast")
fx, _, fz = FEAST
b.detail("Cloth", "Feast", (fx, 0.02, fz), (8, 0.04, 6), "cloth_pale")
b.detail("Cloth2", "Feast", (fx - 1.2, 0.03, fz + 0.8), (4.5, 0.04, 3.5), "coat", yaw=0.2)
for i, (dx, dz, r, h) in enumerate(((-3.2, -1.4, 0.32, 0.56), (-3.6, 0.4, 0.28, 0.48), (3.4, 1.6, 0.3, 0.52), (3.7, -0.6, 0.26, 0.44))):
    b.detail_cyl(f"Pot{i}", "Feast", (fx + dx, h / 2, fz + dz), r, h, "plaster_ochre")
for i, (dx, dz) in enumerate(((-1.8, -1.0), (-0.6, 1.2), (0.9, -1.6), (2.0, 0.8), (0.2, 0.1), (-2.4, 1.8))):
    b.detail_cyl(f"Bowl{i}", "Feast", (fx + dx, 0.09, fz + dz), 0.26, 0.1, "plaster_white")
b.detail_cyl("Basket", "Feast", (fx + 2.6, 0.22, fz - 2.2), 0.42, 0.44, "timber")
b.collider("PotBodies", "Feast", (0.7, 0.6, 0.7), [((fx - 3.4, 0.3, fz - 0.5), 0.0), ((fx + 3.5, 0.3, fz + 0.5), 0.0)])
# Lalita (GDD §4: bright, bossy, laughing; the water-carrying task) faces
# the cloth; the pot goes beside her (scripts/grove/pot_place.gd).
keeper("Lalita", "Feast", "humanFemaleA", ["lalita_thanks", "lalita_carrying", "lalita_greet"], LALITA, NORTH)
b.nodes.append(
    '[node name="PotPlace" type="Node3D" parent="Feast"]\n'
    "unique_name_in_owner = true\n"
    f"transform = {xf(POT_PLACE)}\n"
    'script = ExtResource("pot_place")\n'
    'item = "pot"\nevent = "pot_placed"\n\n'
    '[node name="Place" type="Area3D" parent="Feast/PotPlace"]\n'
    'script = ExtResource("2_interact")\n'
    'verb_id = "verb.place"\n\n'
    '[node name="Shape" type="CollisionShape3D" parent="Feast/PotPlace/Place"]\n'
    f"transform = {xf((0, 1.0, 0))}\n"
    'shape = SubResource("CylinderShape3D_near")\n\n'
    '[node name="PlacedPot" parent="Feast/PotPlace" instance=ExtResource("pot")]\n'
    "unique_name_in_owner = true\n"
    "visible = false\n"
    f"transform = {xf((0, 0.45, 0))}\n\n"
)
# Two friends at the feast, with nothing to say yet (GDD §3: "Friends are
# preparing a feast"). PLACEHOLDER: the street's skins; the Grove's company
# of children wears the two Grove heads of GDD §4.
FRIENDS = [("skaterFemaleA", (fx - 4.6, 0.0, fz + 1.4), EAST), ("humanMaleA", (fx + 4.4, 0.0, fz - 1.6), WEST)]
for i, (skin, pos, yaw) in enumerate(FRIENDS):
    b.figure(f"Friend{i}", "Feast", skin, pos, yaw=yaw)
b.collider("FriendBodies", "Feast", (0.6, 1.8, 0.6), [((p[0], 0.9, p[2]), 0.0) for _, p, _ in FRIENDS])

# --- the calf meadow ----------------------------------------------------------
b.group("Meadow")
b.nodes.append(
    '[node name="Calf" parent="Meadow" instance=ExtResource("calf")]\n'
    "unique_name_in_owner = true\n"
    f"transform = {xf(MEADOW, WEST)}\n"
    "wander_radius = 8.0\n\n"
)
mx, _, mz = MEADOW
bush_spots = [(mx - 10, mz + 4), (mx - 8, mz + 9), (mx + 11, mz + 6), (mx + 9, mz - 7), (mx - 3, mz + 11)]
shrubs("MeadowShrubs", "Meadow", bush_spots, 2.6)

# --- the flower garden --------------------------------------------------------
# Marigold, jasmine white, rose and amber (GDD §10 Grove accents): one
# MultiMesh of petal quads with a colour each, one of stems.
b.group("Garden")
gx, _, gz = GARDEN
gw, gd = GARDEN_SIZE
PETALS = [(1.0, 0.62, 0.12, 1.0), (0.98, 0.96, 0.9, 1.0), (0.96, 0.5, 0.52, 1.0), (1.0, 0.8, 0.3, 1.0)]
petals, stems = [], []
for _ in range(260):
    x = gx + rng.uniform(-gw / 2, gw / 2)
    z = gz + rng.uniform(-gd / 2, gd / 2)
    height = rng.uniform(0.18, 0.34)
    size = rng.uniform(0.16, 0.26)
    petals.append((tilted_quad(rng.uniform(0, 6.28), rng.uniform(-0.35, 0.35), size), (x, height, z), rng.choice(PETALS)))
    stems.append(((x, height / 2, z), 0.0, (0.025, height, 0.025)))
colour_multimesh("Petals", "Garden", "QuadMesh_petal", "petal", petals)
b.multimesh("Stems", "Garden", "BoxMesh_unit", "grass", stems, shadows=False)
garden_bushes = [(gx - gw / 2 - 1.5, gz - 3), (gx - gw / 2 - 1.2, gz + 3.5), (gx + 2, gz - gd / 2 - 1.6), (gx - 4, gz + gd / 2 + 1.8)]
shrubs("GardenShrubs", "Garden", garden_bushes, 2.2)

# --- the kadamba tree and its swing ------------------------------------------
# PLACEHOLDER kadamba: Quaternius' Tree_1 at a larger scale; the kadamba is
# custom art in GDD §10 "Asset sourcing plan".
b.group("Kadamba")
kx, _, kz = KADAMBA
b.model("KadambaTree", "Kadamba", "tree_1", KADAMBA, 1.1, 1.35)
b.collider("KadambaTrunk", "Kadamba", (0.9, 4.0, 0.9), [((kx, 2.0, kz), 0.0)])
BRANCH_Y = 4.0
b.cyl("Branch", "Kadamba", (kx + 1.8, BRANCH_Y, kz), 0.14, 3.6, "timber", lay=True)
swing_x = kx + 3.2
b.nodes.append(
    '[node name="Swing" type="Node3D" parent="Kadamba"]\n'
    "unique_name_in_owner = true\n"
    f"transform = {xf((swing_x, 0.0, kz))}\n"
    'script = ExtResource("swing")\n'
    'flag = "swing_pushed"\nsubtitle_id = "sub.lalita_laughs"\n\n'
    '[node name="Pivot" type="Node3D" parent="Kadamba/Swing"]\n'
    f"transform = {xf((0, BRANCH_Y, 0))}\n\n"
)
for side, dx in (("L", -0.45), ("R", 0.45)):
    b.detail_cyl(f"Rope{side}", "Kadamba/Swing/Pivot", (dx, -1.65, 0), 0.025, 3.3, "timber")
b.detail("Seat", "Kadamba/Swing/Pivot", (0, -3.32, 0), (1.1, 0.06, 0.4), "timber")
b.nodes.append(
    '[node name="Push" type="Area3D" parent="Kadamba/Swing"]\n'
    'script = ExtResource("2_interact")\n'
    'verb_id = "verb.push"\n\n'
    '[node name="Shape" type="CollisionShape3D" parent="Kadamba/Swing/Push"]\n'
    f"transform = {xf((0, 1.0, 0))}\n"
    f'shape = SubResource("{b.shape_id((2.6, 2.0, 2.8))}")\n\n'
)

# --- the Pool at the Grove's edge --------------------------------------------
b.group("Pool")
px, _, pz = POOL
b.detail_cyl("Disc", "Pool", (px, -0.08, pz), POOL_R, 0.1, "pool")
b.nodes.append(
    '[node name="Rim" type="MeshInstance3D" parent="Pool"]\n'
    f"transform = {xf((px, -0.04, pz), 0.0, (1, 0.4, 1))}\n"
    'mesh = SubResource("TorusMesh_rim")\n'
    f'surface_material_override/0 = ExtResource("{MAT_ID["plaster_ochre"]}")\n\n'
    # Nobody walks on the Pool: the way in is the Dive, at its edge.
    '[node name="Still" type="StaticBody3D" parent="Pool"]\n'
    "collision_layer = 1\ncollision_mask = 0\n\n"
    '[node name="Shape" type="CollisionShape3D" parent="Pool/Still"]\n'
    f"transform = {xf((px, 0.5, pz))}\n"
    'shape = SubResource("CylinderShape3D_pool")\n\n'
)
# The Dive (GDD §3 Act 1 "The choice"): the door leads into the Veil's fall
# (place "veil_down", built apart), which ends on the street's
# "fountain_basin" spawn (tools/street_parts/basin_spawn.py). The Stay/Dive
# prompt is later work. "pool_bank" is where the Veil's ascent ("veil_up")
# and the street's development door land.
b.door("DiveDoor", "Pool", "veil_down", "fountain_basin", "verb.dive", (px - POOL_R - 0.7, 0.0, pz), size=(3.0, 2.2, 3.4))
b.spawn("SpawnPoolBank", "Pool", "pool_bank", (px - POOL_R - 2.4, 0.0, pz), WEST)

# --- drifting bubbles ---------------------------------------------------------
b.group("Bubbles")
BUBBLES = [((-8.0, 1.5, -22.0), 0.0), ((-10.0, 1.6, 1.0), 1.1), ((4.0, 1.4, 11.0), 2.2),
           ((-22.0, 1.5, -5.0), 3.3), ((25.0, 1.6, 11.0), 4.4), ((15.0, 1.6, -11.0), 5.5)]
for i, (pos, phase) in enumerate(BUBBLES):
    b.nodes.append(
        f'[node name="Bubble{i}" parent="Bubbles" instance=ExtResource("bubble")]\n'
        f"transform = {xf(pos)}\n"
        f"phase = {phase:g}\nperiod = {26.0 + i * 3.0:g}\n\n"
    )

# --- trees round the edge -----------------------------------------------------
b.group("Trees")
south_spots = [(x, HALF_D - 2.5) for x in range(-36, 37, 9)]
east_spots = [(HALF_W - 2.5, z) for z in range(-26, 6, 8)]
west_spots = [(-HALF_W + 2.5, z) for z in range(-26, 27, 9)]
tree_batch("Trees_tree_1", "Trees", "tree_1", south_spots[0::2] + west_spots[1::2], 1.0)
tree_batch("Trees_tree_3", "Trees", "tree_3", south_spots[1::2] + west_spots[0::2], 1.05)
tree_batch("Trees_birch_4", "Trees", "birch_4", east_spots[0::2], 1.0)
tree_batch("Trees_pine_2", "Trees", "pine_2", east_spots[1::2], 0.95)

# --- the stars ----------------------------------------------------------------
# A dome of tiny unlit quads, warm white, brightness per star (GDD §5 "a sky
# with visible stars"). Inside the camera's far plane, above the fog's reach.
b.group("Sky")
stars = []
for _ in range(STAR_COUNT):
    azimuth = rng.uniform(0, 6.28)
    elevation = math.radians(rng.uniform(12, 88))
    d = (math.cos(elevation) * math.sin(azimuth), math.sin(elevation), math.cos(elevation) * math.cos(azimuth))
    pos = tuple(c * STAR_DOME for c in d)
    size = rng.uniform(0.8, 1.6)
    glow = rng.uniform(0.55, 1.0)
    stars.append((facing_quad(d, size), pos, (glow, glow * 0.97, glow * 0.9, 1.0)))
colour_multimesh("Stars", "Sky", "QuadMesh_star", "star", stars)

# ================================================================ assembly

header = (
    "[gd_scene load_steps=STEPS format=3]\n\n"
    "; The Grove riverbank, Act 1. GENERATED by tools/gen_grove.py; edit that,\n"
    "; not this. GDD §3 Act 1, §3a, §5 \"The Grove riverbank\", §8 Scene A.\n;\n"
    "; PLACEHOLDER: primitives with the street's procedural textures and CC0\n"
    "; stand-in models (docs/RIGHTS_REGISTER.md). Replaced by the painted\n"
    "; stylized 3D of GDD §10. Palette: GDD §10 Grove row, rose-gold dusk,\n"
    "; without peacock blue or magenta (CLAUDE.md).\n\n"
    '[ext_resource type="Script" path="res://scripts/places/place.gd" id="1_place"]\n'
    '[ext_resource type="PackedScene" path="res://scenes/npc/Shopkeeper.tscn" id="keeper"]\n'
    '[ext_resource type="PackedScene" path="res://scenes/grove/Calf.tscn" id="calf"]\n'
    '[ext_resource type="PackedScene" path="res://scenes/grove/Bubble.tscn" id="bubble"]\n'
    '[ext_resource type="PackedScene" path="res://scenes/quest/Pot.tscn" id="pot"]\n'
    '[ext_resource type="Script" path="res://scripts/quest/pickup_item.gd" id="pickup"]\n'
    '[ext_resource type="Script" path="res://scripts/grove/pot_place.gd" id="pot_place"]\n'
    '[ext_resource type="Script" path="res://scripts/grove/swing.gd" id="swing"]\n'
    '[ext_resource type="Script" path="res://scripts/grove/far_figure.gd" id="far_figure"]\n'
    '[ext_resource type="Material" path="res://assets/materials/far_figure.tres" id="mat_far_figure"]\n'
    + "".join(
        f'[ext_resource type="Material" path="res://assets/materials/{m}.tres" id="{i}"]\n'
        for m, i in GROVE_MATS.items()
    )
    + COMMON_EXT + ext_skins() + ext_models() + ext_materials() + MESHES
    + """[sub_resource type="CylinderShape3D" id="CylinderShape3D_near"]
radius = 1.6
height = 2.4

[sub_resource type="CylinderShape3D" id="CylinderShape3D_pool"]
radius = 6.2
height = 1.6

[sub_resource type="TorusMesh" id="TorusMesh_rim"]
inner_radius = 5.9
outer_radius = 6.9
rings = 48
ring_segments = 8

[sub_resource type="PlaneMesh" id="QuadMesh_petal"]
size = Vector2(1, 1)

[sub_resource type="PlaneMesh" id="QuadMesh_star"]
size = Vector2(1, 1)

; Rose-gold dusk (GDD §5, §10 Grove row): a rose zenith, an amber horizon,
; the low sun drawn by the light below. No magenta, no blue.
[sub_resource type="ProceduralSkyMaterial" id="Sky_dusk"]
sky_top_color = Color(0.44, 0.26, 0.29, 1)
sky_horizon_color = Color(0.98, 0.64, 0.5, 1)
sky_curve = 0.12
sky_energy_multiplier = 1.0
ground_bottom_color = Color(0.3, 0.2, 0.16, 1)
ground_horizon_color = Color(0.9, 0.6, 0.48, 1)
ground_curve = 0.08
sun_angle_max = 32.0
sun_curve = 0.14
use_debanding = true

[sub_resource type="Sky" id="Sky_grove"]
sky_material = SubResource("Sky_dusk")
radiance_size = 2

[sub_resource type="Environment" id="Environment_grove"]
background_mode = 2
sky = SubResource("Sky_grove")
ambient_light_source = 3
ambient_light_sky_contribution = 1.0
ambient_light_energy = 1.15
reflected_light_source = 2
tonemap_mode = 2
tonemap_exposure = 1.0
fog_enabled = true
fog_light_color = Color(0.96, 0.74, 0.62, 1)
fog_density = 0.0016
fog_aerial_perspective = 0.5
fog_sky_affect = 0.25

"""
)

root = (
    '[node name="Grove" type="Node3D"]\n'
    'script = ExtResource("1_place")\n'
    'place_id = "grove"\n\n'
    '[node name="Environment" type="WorldEnvironment" parent="."]\n'
    'environment = SubResource("Environment_grove")\n\n'
    "; The low pink-gold sun of the eternal dusk, over the far bank: long warm\n"
    "; shadows (GDD §5). Real-time shadow as the stand-in for a bake, as in the\n"
    "; street.\n"
    '[node name="Sun" type="DirectionalLight3D" parent="."]\n'
    f"transform = {look_xf(SUN_DIRECTION, (0, 30, 0))}\n"
    "light_color = Color(1, 0.74, 0.6, 1)\nlight_energy = 1.3\nlight_bake_mode = 2\n"
    "shadow_enabled = true\nshadow_opacity = 0.7\nshadow_bias = 0.06\nshadow_normal_bias = 1.5\n"
    "directional_shadow_mode = 0\ndirectional_shadow_max_distance = 60.0\n"
    "directional_shadow_fade_start = 0.85\n\n"
)

footer = f"""; A fresh journey wakes on the grass beside the river, facing the water
; (GDD §3 Act 1 "Waking"). A journey through a door lands on its spawn point.
[node name="Player" parent="." instance=ExtResource("4_player")]
unique_name_in_owner = true
transform = {xf(WAKE, NORTH)}

[node name="CameraRig" parent="." instance=ExtResource("5_rig")]
unique_name_in_owner = true
target_path = NodePath("../Player")

[node name="UI" type="CanvasLayer" parent="."]

[node name="TouchControls" parent="UI" instance=ExtResource("6_controls")]
unique_name_in_owner = true
"""


def render() -> str:
    b.flush_details()
    return finish(header + b.shape_defs() + "".join(b.multimeshes) + root + "".join(b.nodes) + footer)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    text = render()
    if args.check:
        if not OUT.exists() or OUT.read_text() != text:
            print("gen_grove: scenes/places/Grove.tscn is stale; run tools/gen_grove.py", file=sys.stderr)
            return 1
        print("gen_grove: Grove.tscn is current")
        return 0
    OUT.write_text(text)
    print(f"gen_grove: wrote {OUT.relative_to(ROOT)}: {len(b.nodes)} node blocks, "
          f"{len(b.multimeshes)} multimeshes, {len(b.shapes)} shapes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
