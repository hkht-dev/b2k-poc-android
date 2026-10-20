#!/usr/bin/env python3
"""Generate scenes/places/Home.tscn — the riverbank at the end of the journey.

GDD §3 Act 5 "Home", §3a Act 5, §8 Scene F. A small clearing in rose-gold
light: a disc of warm earth, the river along its north side, three trees,
warm fog, stars on a far dome, and a figure standing in the shallows that the
player wades toward. Built like the street and the shop insides, from
primitives and the same CC0 models through tools/scenegen.py, with the same
player, camera and HUD; the script is scripts/places/home.gd, a Place.

    python3 tools/gen_home.py           # writes scenes/places/Home.tscn
    python3 tools/gen_home.py --check   # fails if the committed scene is stale

Layout: X east, Z south, Y up. The bank is centred on the origin; the river
lies to the north; the player arrives on the south bank facing it.
"""

from __future__ import annotations

import argparse
import math
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "scenes" / "places" / "Home.tscn"

sys.path.insert(0, str(Path(__file__).resolve().parent))
from scenegen import (  # noqa: E402
    COMMON_EXT, MESHES, MODEL_ID, MODELS, Builder, ext_materials, finish, instance_floats, xf,
)

# Home's own materials beside the street's (assets/materials/<name>.tres).
HOME_MATS = {
    "home_water": "mat_water",
    "home_indigo": "mat_indigo",
    "home_yellow": "mat_yellow",
    "garland": "mat_garland",
    "star": "mat_star",
}
# Quaternius' textured trees (CC0, docs/RIGHTS_REGISTER.md), three on the bank.
TREES = ["tree_3", "birch_1", "tree_5"]
TREE_SPOTS = [(-8.5, 0.0, 2.5), (9.5, 0.0, -0.5), (-4.5, 0.0, -4.0)]
FIGURE_AT = (0.0, 0.0, -12.0)
BANK_AT = (0.0, 0.0, 5.0)
SOUTH = math.pi  # a body yaw facing +Z (toward the arriving player)
NORTH = 0.0

SKY = """[sub_resource type="ProceduralSkyMaterial" id="Sky_home_material"]
sky_top_color = Color(0.2, 0.13, 0.32, 1)
sky_horizon_color = Color(0.98, 0.66, 0.52, 1)
sky_curve = 0.1
ground_bottom_color = Color(0.34, 0.22, 0.26, 1)
ground_horizon_color = Color(0.98, 0.66, 0.52, 1)
ground_curve = 0.08
sun_angle_max = 25.0
sun_curve = 0.2

[sub_resource type="Sky" id="Sky_home"]
sky_material = SubResource("Sky_home_material")
radiance_size = 2

[sub_resource type="Environment" id="Environment_home"]
background_mode = 2
sky = SubResource("Sky_home")
ambient_light_source = 2
ambient_light_color = Color(0.7, 0.52, 0.56, 1)
ambient_light_sky_contribution = 0.5
ambient_light_energy = 1.0
reflected_light_source = 2
tonemap_mode = 2
tonemap_exposure = 1.05
fog_enabled = true
fog_light_color = Color(0.98, 0.72, 0.6, 1)
fog_light_energy = 1.0
fog_sun_scatter = 0.25
fog_density = 0.03
fog_aerial_perspective = 0.4
fog_sky_affect = 0.15

"""


def mesh(b: Builder, name, parent, mesh_id, pos, scale, mat_ext, yaw=0.0, shadows=True, transform=None) -> None:
    """A primitive in one of Home's own materials (not in scenegen's table)."""
    t = transform or xf(pos, yaw, scale)
    b.nodes.append(
        f'[node name="{name}" type="MeshInstance3D" parent="{parent}"]\n'
        f"transform = {t}\n"
        f'mesh = SubResource("{mesh_id}")\n'
        f'surface_material_override/0 = ExtResource("{mat_ext}")\n'
        + ("" if shadows else "cast_shadow = 0\n")
        + "\n"
    )


def bank(b: Builder) -> None:
    b.group("Bank")
    # A disc of warm earth; an unseen floor far past it so the fog's edge is
    # never a cliff.
    b.cyl("Disc", "Bank", (0, -0.25, 0), 24.0, 0.5, "plaster_ochre")
    b.collider("Floor", "Bank", (160, 1.0, 160), [((0, -0.5, 0), 0.0)])
    # The river, north: a thin sheet the player wades into (no collision).
    mesh(b, "Water", "Bank", "BoxMesh_unit", (0, 0.04, -24), (90, 0.12, 36), "mat_water", shadows=False)
    for kind, (x, y, z) in zip(TREES, TREE_SPOTS):
        b.model(f"Tree_{kind}", "Bank", kind, (x, y, z), yaw=(x * 0.7) % 6.28, scale=0.9)
    b.collider("Trunks", "Bank", (0.6, 4.0, 0.6), [((x, 2.0, z), 0.0) for x, _, z in TREE_SPOTS])


def stars(b: Builder, count: int = 180, radius: float = 140.0, seed: int = 5) -> None:
    """Stars on a far dome: one MultiMesh, one draw call, outside the fog
    (assets/materials/star.tres). Seeded, so the scene is reproducible."""
    rnd = random.Random(seed)
    instances = []
    for _ in range(count):
        azimuth = rnd.uniform(0.0, 2 * math.pi)
        elevation = math.radians(rnd.uniform(12.0, 88.0))
        size = rnd.uniform(0.3, 0.75)
        pos = (
            radius * math.cos(elevation) * math.sin(azimuth),
            radius * math.sin(elevation),
            radius * math.cos(elevation) * math.cos(azimuth),
        )
        instances.append((pos, 0.0, (size, size, size)))
    b.group("Sky")
    b.multimeshes.append(
        '[sub_resource type="MultiMesh" id="MultiMesh_Stars"]\n'
        "transform_format = 1\n"
        'mesh = SubResource("BoxMesh_unit")\n'
        f"instance_count = {count}\n"
        f"buffer = PackedFloat32Array({instance_floats(instances)})\n\n"
    )
    b.nodes.append(
        '[node name="Stars" type="MultiMeshInstance3D" parent="Sky"]\n'
        'multimesh = SubResource("MultiMesh_Stars")\n'
        'material_override = ExtResource("mat_star")\n'
        "cast_shadow = 0\n\n"
    )


def figure(b: Builder) -> None:
    """Krishna, standing in the shallows, facing the bank (GDD §8 Scene F).

    PLACEHOLDER: primitives in indigo and yellow cloth with a feather and a
    flute; replaced by the painted Krishna of GDD §10 "Characters" (dark-blue
    skin, yellow cloth, tilak, peacock feather, jasmine garland, aura) after
    the panel's review (GDD §15). The head is its own node so the script can
    bow it; the garland is hidden until it is given."""
    b.nodes.append(
        '[node name="Figure" type="Node3D" parent="."]\n'
        "unique_name_in_owner = true\n"
        f"transform = {xf(FIGURE_AT, SOUTH)}\n\n"
    )
    mesh(b, "Cloth", "Figure", "BoxMesh_unit", (0, 0.45, 0), (0.46, 0.9, 0.3), "mat_yellow")
    mesh(b, "Torso", "Figure", "CylinderMesh_unit", (0, 1.21, 0), (0.4, 0.62, 0.4), "mat_indigo")
    for side, x in (("L", -0.27), ("R", 0.27)):
        mesh(b, f"Arm{side}", "Figure", "CylinderMesh_unit", (x, 1.18, 0), (0.12, 0.56, 0.12), "mat_indigo")
    b.cyl("Flute", "Figure", (0.33, 0.95, -0.14), 0.017, 0.5, "timber", yaw=0.7, lay=True)
    b.nodes.append(
        '[node name="Head" type="Node3D" parent="Figure"]\n'
        "unique_name_in_owner = true\n"
        f"transform = {xf((0, 1.58, 0))}\n\n"
    )
    mesh(b, "Skull", "Figure/Head", "SphereMesh_unit", (0, 0.15, 0), (0.3, 0.3, 0.3), "mat_indigo")
    # The feather in the hair: the Glimpse's own quad, allowed its blue here.
    b.nodes.append(
        '[node name="Crest" parent="Figure/Head" instance=ExtResource("feather")]\n'
        "transform = Transform3D(0.6, 0, 0, 0, 0.2, 0.57, 0, -0.57, 0.2, 0.06, 0.26, -0.02)\n\n"
    )
    b.nodes.append(
        '[node name="Garland" parent="Figure" instance=ExtResource("garland")]\n'
        "unique_name_in_owner = true\n"
        "visible = false\n"
        "transform = Transform3D(1.5, 0, 0, 0, 1.5, 0, 0, 0, 1.5, 0, 1.4, -0.02)\n\n"
    )
    b.collider("Body", "Figure", (0.7, 1.8, 0.7), [((0, 0.9, 0), 0.0)])
    # Backlit by a warm source the rest of the scene does not have (GDD §10).
    b.nodes.append(
        '[node name="Backlight" type="OmniLight3D" parent="."]\n'
        f"transform = {xf((FIGURE_AT[0], 1.7, FIGURE_AT[2] - 1.4))}\n"
        "light_color = Color(1, 0.74, 0.46, 1)\nlight_energy = 2.5\n"
        "omni_range = 5.0\nshadow_enabled = false\n\n"
    )
    # The one verb in the scene (GDD §3 Act 5: "one tap: the garland"),
    # offered only with the garland from the Grove.
    b.nodes.append(
        '[node name="Offer" type="Area3D" parent="."]\n'
        "unique_name_in_owner = true\n"
        f"transform = {xf(FIGURE_AT)}\n"
        'script = ExtResource("2_interact")\n'
        'verb_id = "verb.garland"\n'
        'requires = PackedStringArray("garland_made")\n\n'
        '[node name="Shape" type="CollisionShape3D" parent="Offer"]\n'
        f"transform = {xf((0, 1.2, 0))}\n"
        f'shape = SubResource("{b.shape_id((3.4, 2.4, 3.4))}")\n\n'
    )


def home() -> str:
    b = Builder()
    bank(b)
    stars(b)
    figure(b)
    # Where the door in the street's basin lands the player (GDD §3 Act 5
    # "The embrace": breaks the surface of the Pool and wades to the bank).
    b.spawn("SpawnBank", ".", "bank", BANK_AT, NORTH)
    return assemble(b)


def assemble(b: Builder) -> str:
    header = (
        "[gd_scene load_steps=STEPS format=3]\n\n"
        "; Home — the riverbank at the end of the journey. GENERATED by\n"
        "; tools/gen_home.py; edit that, not this. GDD §3 Act 5, §3a Act 5, §8\n"
        "; Scene F.\n;\n"
        "; PLACEHOLDER: primitives, the street's procedural textures and CC0 trees\n"
        "; (docs/RIGHTS_REGISTER.md). Replaced by the painted bank of GDD §10.\n"
        "; Palette: GDD §10, Grove row, rose-gold dusk, without its magenta sky by\n"
        '; decision (docs/DECISIONS.md "Remembrance and Home"). Krishna\'s indigo\n'
        "; is allowed here and is the panel's to review.\n\n"
        '[ext_resource type="Script" path="res://scripts/places/home.gd" id="1_home"]\n'
        '[ext_resource type="PackedScene" path="res://scenes/quest/Feather.tscn" id="feather"]\n'
        '[ext_resource type="PackedScene" path="res://scenes/quest/Garland.tscn" id="garland"]\n'
        + COMMON_EXT
        + "".join(
            f'[ext_resource type="PackedScene" path="res://assets/thirdparty/{MODELS[m]}" id="{MODEL_ID[m]}"]\n'
            for m in TREES
        )
        + ext_materials()
        + "".join(
            f'[ext_resource type="Material" path="res://assets/materials/{m}.tres" id="{i}"]\n'
            for m, i in HOME_MATS.items()
        )
        + MESHES
        + SKY
    )
    root = (
        '[node name="Home" type="Node3D"]\n'
        'script = ExtResource("1_home")\n'
        'place_id = "home"\n'
        'stand_in_flags = PackedStringArray("garland_made")\n\n'
        '[node name="Environment" type="WorldEnvironment" parent="."]\n'
        'environment = SubResource("Environment_home")\n\n'
        "; Dusk from the far bank: low, rose-gold, behind Him (GDD §10: \"a figure\n"
        '; small against a huge sunset").\n'
        '[node name="Sun" type="DirectionalLight3D" parent="."]\n'
        "transform = Transform3D(-1, 0, 0, 0, 0.954, 0.3, 0, 0.3, -0.954, 0, 20, -30)\n"
        "light_color = Color(1, 0.78, 0.62, 1)\nlight_energy = 1.2\n"
        "shadow_enabled = true\nshadow_opacity = 0.6\n"
        "directional_shadow_mode = 0\ndirectional_shadow_max_distance = 40.0\n\n"
    )
    footer = f"""[node name="Player" parent="." instance=ExtResource("4_player")]
unique_name_in_owner = true
transform = {xf(BANK_AT, NORTH)}

[node name="CameraRig" parent="." instance=ExtResource("5_rig")]
unique_name_in_owner = true
target_path = NodePath("../Player")

[node name="UI" type="CanvasLayer" parent="."]

[node name="TouchControls" parent="UI" instance=ExtResource("6_controls")]
unique_name_in_owner = true
"""
    return finish(header + b.shape_defs() + "".join(b.multimeshes) + root + "".join(b.nodes) + footer)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    text = home()
    if args.check:
        if not OUT.exists() or OUT.read_text() != text:
            print("gen_home: scenes/places/Home.tscn is stale; run tools/gen_home.py", file=sys.stderr)
            return 1
        print("gen_home: Home.tscn is current")
        return 0
    OUT.write_text(text)
    print(f"gen_home: wrote {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
