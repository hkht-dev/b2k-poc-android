"""Shared pieces of the scene generators (tools/gen_street.py, tools/gen_interiors.py).

A generated scene is a list of node blocks, a table of box shapes they share
and the MultiMeshes they reference; the Builder collects all three. The
material and model tables are the same for every generated scene so that a
shop's inside is built from the street's own textures and CC0 models
(docs/RIGHTS_REGISTER.md).

Layout convention, as in the street: X east, Z south, Y up.
"""

from __future__ import annotations

import math
import re

MATS = [
    "plaster_ochre", "plaster_white", "plaster_cream", "brick", "concrete_dust",
    "asphalt", "timber", "corrugated", "rust_metal", "coat", "cloth_pale", "skin",
    "road_paint", "tyre",
    # CC0, Poly Haven, via tools/fetch_polyhaven.py — see docs/RIGHTS_REGISTER.md
    "ph_asphalt", "ph_concrete", "ph_plaster", "ph_brick", "ph_corrugated",
    "sign", "canopy",
    # tools/texture_parts/world.py: the Grove and the interiors (GDD §5, §10).
    # Appended so the ids above never move.
    "grass", "river_bed", "tile_floor", "parquet", "fabric_print",
    "chalkboard", "paper", "stone_old", "bark_kadamba", "sari_red",
]
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

# Kenney's animated-characters skins (pack -> skins), all on the same body;
# docs/RIGHTS_REGISTER.md. The player wears humanMaleA (Player.tscn) and
# Tulu skaterMaleA (Tulu.tscn); the pedestrians cycle through the rest.
SKIN_PACKS = {
    "animated-characters-retro": ["humanFemaleA", "humanMaleA"],
    "animated-characters-protagonists": ["criminalMaleA", "skaterFemaleA", "skaterMaleA"],
    "animated-characters-survivors": ["survivorFemaleA", "survivorMaleB"],
}
SKIN_PATH = {skin: f"{pack}/{skin}.png" for pack, skins in SKIN_PACKS.items() for skin in skins}

# ext_resource ids every generated scene shares for its scripts and scenes.
COMMON_EXT = (
    '[ext_resource type="PackedScene" path="res://scenes/player/Player.tscn" id="4_player"]\n'
    '[ext_resource type="PackedScene" path="res://scenes/player/CameraRig.tscn" id="5_rig"]\n'
    '[ext_resource type="PackedScene" path="res://scenes/ui/TouchControls.tscn" id="6_controls"]\n'
    '[ext_resource type="PackedScene" path="res://scenes/characters/Character.tscn" id="8_character"]\n'
    '[ext_resource type="Script" path="res://scripts/street/model_batch.gd" id="batch"]\n'
    '[ext_resource type="Script" path="res://scripts/lib/interactable.gd" id="2_interact"]\n'
    '[ext_resource type="Script" path="res://scripts/lib/label_from_id.gd" id="label_id"]\n'
    '[ext_resource type="PackedScene" path="res://scenes/places/Door.tscn" id="door"]\n'
    '[ext_resource type="Script" path="res://scripts/places/spawn_point.gd" id="spawn"]\n'
)

MESHES = """
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

[sub_resource type="SphereMesh" id="SphereMesh_unit"]
radius = 0.5
height = 1.0
radial_segments = 12
rings = 6

"""


def ext_skins() -> str:
    return "".join(
        f'[ext_resource type="Texture2D" path="res://assets/thirdparty/kenney/{path}" id="skin_{skin}"]\n'
        for skin, path in SKIN_PATH.items()
    )


def ext_models() -> str:
    return "".join(
        f'[ext_resource type="PackedScene" path="res://assets/thirdparty/{path}" id="{MODEL_ID[m]}"]\n'
        for m, path in MODELS.items()
    )


def ext_materials() -> str:
    return "".join(
        f'[ext_resource type="Material" path="res://assets/materials/{m}.tres" id="{MAT_ID[m]}"]\n'
        for m in MATS
    )


def xf(pos=(0, 0, 0), yaw=0.0, scale=(1, 1, 1)) -> str:
    c, s = math.cos(yaw), math.sin(yaw)
    v = [c * scale[0], 0, -s * scale[0], 0, scale[1], 0, s * scale[2], 0, c * scale[2], *pos]
    return "Transform3D(" + ", ".join(f"{n:g}" for n in v) + ")"


def instance_floats(instances) -> str:
    floats = []
    for pos, yaw, scale in instances:
        c, s = math.cos(yaw), math.sin(yaw)
        sx, sy, sz = scale
        # Godot's 3D MultiMesh buffer: 12 floats per instance, the 3x4 matrix
        # row by row: (bx.x, by.x, bz.x, o.x, bx.y, by.y, bz.y, o.y, bx.z, ...).
        floats += [c * sx, 0, s * sz, pos[0], 0, sy, 0, pos[1], -s * sx, 0, c * sz, pos[2]]
    return ", ".join(f"{f:g}" for f in floats)


def finish(body: str) -> str:
    """Fills in load_steps once the whole scene text is assembled."""
    steps = body.count("[ext_resource ") + body.count("[sub_resource ") + 1
    return body.replace("load_steps=STEPS", f"load_steps={steps}", 1)


class Builder:
    """Collects node blocks, shared box shapes and MultiMeshes for one scene."""

    def __init__(self) -> None:
        self.nodes: list[str] = []
        self.shapes: dict[tuple, str] = {}
        self.multimeshes: list[str] = []
        self.details = {}

    def shape_id(self, size) -> str:
        key = tuple(round(v, 4) for v in size)
        if key not in self.shapes:
            self.shapes[key] = f"BoxShape3D_{len(self.shapes)}"
        return self.shapes[key]

    def shape_defs(self) -> str:
        return "".join(
            f'[sub_resource type="BoxShape3D" id="{sid}"]\nsize = Vector3({k[0]:g}, {k[1]:g}, {k[2]:g})\n\n'
            for k, sid in self.shapes.items()
        )

    # A collision-less box or cylinder smaller than this on every side is a
    # detail (a sign, a cup, a coin, a frame) and casts no shadow: the shadow
    # pass is a draw call per caster, and the expansion's props pushed the
    # street past 200 at the worst angle (docs/DECISIONS.md "Budget after the
    # expansion"). Pass shadows=True to keep a small thing's shadow.
    DETAIL_SIZE = 1.5
    # The root node the scene-wide detail buckets hang from.
    DETAILS_ROOT = "Details"
    # A detail is small. Anything bigger on any side is structure — a road,
    # a basin, a wall panel — and stays a node of its own under its group,
    # where the minimap, the Path card and the tests look for it by name.
    BATCH_LIMIT = 3.0

    def solid(self, name, parent, pos, size, mat, yaw=0.0, collide=True, shadows=None) -> None:
        """A box. With collision it is a StaticBody3D; without, a bare mesh.
        `shadows` None lets the detail rule decide."""
        if shadows is None:
            shadows = collide or max(size) >= self.DETAIL_SIZE
        cast = "" if shadows else "cast_shadow = 0\n"
        if collide:
            self.nodes.append(
                f'[node name="{name}" type="StaticBody3D" parent="{parent}"]\n'
                f"transform = {xf(pos, yaw)}\ncollision_layer = 1\ncollision_mask = 0\n\n"
                f'[node name="Shape" type="CollisionShape3D" parent="{parent}/{name}"]\n'
                f'shape = SubResource("{self.shape_id(size)}")\n\n'
                f'[node name="Mesh" type="MeshInstance3D" parent="{parent}/{name}"]\n'
                f"transform = {xf((0, 0, 0), 0.0, size)}\n"
                f'mesh = SubResource("BoxMesh_unit")\n'
                f'surface_material_override/0 = ExtResource("{MAT_ID[mat]}")\n\n'
            )
        else:
            self.nodes.append(
                f'[node name="{name}" type="MeshInstance3D" parent="{parent}"]\n'
                f"transform = {xf(pos, yaw, size)}\n"
                f'mesh = SubResource("BoxMesh_unit")\n'
                f'surface_material_override/0 = ExtResource("{MAT_ID[mat]}")\n{cast}\n'
            )

    def cyl(self, name, parent, pos, radius, height, mat, yaw=0.0, lay=False, shadows=None) -> None:
        """A cylinder; `lay` rolls it onto its side along X (a wheel, a tank).
        `shadows` None lets the detail rule decide (cylinders never collide)."""
        if shadows is None:
            shadows = max(radius * 2, height) >= self.DETAIL_SIZE
        cast = "" if shadows else "cast_shadow = 0\n"
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
        self.nodes.append(
            f'[node name="{name}" type="MeshInstance3D" parent="{parent}"]\n'
            f"transform = {t}\n"
            f'mesh = SubResource("CylinderMesh_unit")\n'
            f'surface_material_override/0 = ExtResource("{MAT_ID[mat]}")\n{cast}\n'
        )

    def group(self, name, parent=".") -> None:
        self.nodes.append(f'[node name="{name}" type="Node3D" parent="{parent}"]\n\n')

    def multimesh(self, name, parent, mesh_id, mat, instances, shadows=True, mm_id="") -> None:
        """One draw call for every instance. Each instance is (pos, yaw, scale);
        the yaw is Godot's rotation.y. `mat` is a street material's name or an
        ext_resource id of the part's own."""
        mm_id = mm_id or f"MultiMesh_{name}"
        self.multimeshes.append(
            f'[sub_resource type="MultiMesh" id="{mm_id}"]\n'
            f"transform_format = 1\n"
            f'mesh = SubResource("{mesh_id}")\n'
            f"instance_count = {len(instances)}\n"
            f"buffer = PackedFloat32Array({instance_floats(instances)})\n\n"
        )
        cast = "" if shadows else "cast_shadow = 0\n"
        self.nodes.append(
            f'[node name="{name}" type="MultiMeshInstance3D" parent="{parent}"]\n'
            f'multimesh = SubResource("{mm_id}")\n'
            f'material_override = ExtResource("{MAT_ID.get(mat, mat)}")\n{cast}\n'
        )

    # -- details, batched -------------------------------------------------
    # A collision-less box or cylinder is a detail. Each one was a node and a
    # draw call (two with its shadow); the expansion's props took the street's
    # worst angle to 251 against the 200 cap (docs/DECISIONS.md "Budget after
    # the expansion"). Details now go into one MultiMesh per (parent,
    # mesh, material, shadows) and cost one draw call a bucket. The name a
    # part gives a detail is for the reader: a detail is not a node, so a
    # thing a script or a test must find by name stays a solid() or a cyl().

    def detail_mesh(self, parent, mesh_id, mat, pos, rotation_y, scale, shadows) -> None:
        """One instance in the bucket for (mesh, material). Details under a
        top-level group share the scene's bucket (one draw call for every
        timber box in the street); details under a nested node, which may
        move (a gate's leaf), keep a bucket of their own under it.
        `rotation_y` is Godot's rotation.y. `shadows` is kept for the
        caller's record: a bucket casts shadows if any member is not a
        detail-sized thing, and a bucket is one draw call either way."""
        owner = self.DETAILS_ROOT if "/" not in parent and parent != "." else parent
        key = (owner, mesh_id, mat)
        bucket = self.details.setdefault(key, {"instances": [], "shadows": False})
        bucket["instances"].append((pos, rotation_y, scale))
        bucket["shadows"] = bucket["shadows"] or bool(shadows)

    def detail(self, name, parent, pos, size, mat, yaw=0.0, shadows=None) -> None:
        """solid(..., collide=False), batched when it is small enough to be a
        detail. `yaw` is read as solid() reads it (xf's sense:
        rotation.y = -yaw). `name` is documentary for a batched detail and
        the node's name for one that is too big to batch."""
        if max(size) >= self.BATCH_LIMIT:
            self.solid(name, parent, pos, size, mat, yaw, collide=False, shadows=shadows)
            return
        if shadows is None:
            shadows = max(size) >= self.DETAIL_SIZE
        self.detail_mesh(parent, "BoxMesh_unit", mat, pos, -yaw, size, shadows)

    def detail_cyl(self, name, parent, pos, radius, height, mat, yaw=0.0, shadows=None) -> None:
        """An upright cyl(), batched when it is small enough to be a detail."""
        if max(radius * 2, height) >= self.BATCH_LIMIT:
            self.cyl(name, parent, pos, radius, height, mat, yaw, shadows=shadows)
            return
        if shadows is None:
            shadows = max(radius * 2, height) >= self.DETAIL_SIZE
        self.detail_mesh(parent, "CylinderMesh_unit", mat, pos, -yaw, (radius * 2, height, radius * 2), shadows)

    def flush_details(self) -> None:
        """Writes every bucket as one MultiMeshInstance3D: the scene's under a
        root node named DETAILS_ROOT, a nested node's under that node. Call
        once, after every part has built and before the nodes are joined."""
        if any(owner == self.DETAILS_ROOT for owner, _, _ in self.details):
            self.group(self.DETAILS_ROOT)
        kind = {"BoxMesh_unit": "Boxes", "CylinderMesh_unit": "Cylinders", "SphereMesh_unit": "Spheres"}
        for (owner, mesh_id, mat), bucket in self.details.items():
            stem = "".join(word.capitalize() for word in re.split(r"[^A-Za-z0-9]+", mat) if word)
            name = stem + kind.get(mesh_id, mesh_id)
            mm_id = "MultiMesh_" + re.sub(r"[^A-Za-z0-9]+", "_", f"{owner}_{name}")
            self.multimesh(name, owner, mesh_id, mat, bucket["instances"], shadows=bucket["shadows"], mm_id=mm_id)
        self.details = {}

    def batch(self, name, parent, model, instances, shadows=True) -> None:
        """Many copies of a CC0 model, drawn by ModelBatch: one draw call per
        surface. Each instance is (pos, yaw, scale)."""
        cast = "" if shadows else "cast_shadow = false\n"
        self.nodes.append(
            f'[node name="{name}" type="Node3D" parent="{parent}"]\n'
            f'script = ExtResource("batch")\n'
            f'scene = ExtResource("{MODEL_ID[model]}")\n'
            f"transforms = PackedFloat32Array({instance_floats(instances)})\n{cast}\n"
        )

    def model(self, name, parent, which, pos, yaw=0.0, scale=1.0) -> None:
        """One copy of a CC0 model, instanced directly (things that move, one-offs)."""
        self.nodes.append(
            f'[node name="{name}" parent="{parent}" instance=ExtResource("{MODEL_ID[which]}")]\n'
            f"transform = {xf(pos, yaw, (scale, scale, scale))}\n\n"
        )

    def collider(self, name, parent, size, placements) -> None:
        """Collision with no mesh: one StaticBody3D with a box per placement
        (pos, yaw), for props whose look comes from a model or a MultiMesh."""
        self.nodes.append(
            f'[node name="{name}" type="StaticBody3D" parent="{parent}"]\n'
            f"collision_layer = 1\ncollision_mask = 0\n\n"
        )
        for i, (pos, yaw) in enumerate(placements):
            self.nodes.append(
                f'[node name="Shape{i}" type="CollisionShape3D" parent="{parent}/{name}"]\n'
                f"transform = {xf(pos, yaw)}\n"
                f'shape = SubResource("{self.shape_id(size)}")\n\n'
            )

    def figure(self, name, parent, skin, pos=(0, 0, 0), script_props="", scale=1.0, yaw=0.0) -> None:
        """A rigged human (scenes/characters/Character.tscn) with the given skin.
        Pedestrians use it; the player's and Tulu's are instanced in their scenes."""
        self.nodes.append(
            f'[node name="{name}" type="Node3D" parent="{parent}"]\n'
            f"transform = {xf(pos, yaw, (scale, scale, scale))}\n{script_props}\n"
            f'[node name="Figure" parent="{parent}/{name}" instance=ExtResource("8_character")]\n'
            f'skin = ExtResource("skin_{skin}")\n\n'
        )

    def label(self, name, parent, text_id, pos, yaw=0.0, size=48, colour=(0.96, 0.93, 0.85, 1)) -> None:
        """A sign: a Label3D whose text comes from the string table at run time
        (scripts/lib/label_from_id.gd), never baked into the scene."""
        r, g, b, a = colour
        self.nodes.append(
            f'[node name="{name}" type="Label3D" parent="{parent}"]\n'
            f"transform = {xf(pos, yaw)}\n"
            f'script = ExtResource("label_id")\n'
            f'text_id = "{text_id}"\n'
            f"pixel_size = 0.01\nfont_size = {size}\noutline_size = 10\n"
            f"modulate = Color({r:g}, {g:g}, {b:g}, {a:g})\n"
            f"shaded = false\ndouble_sided = false\nno_depth_test = false\ncast_shadow = 0\n\n"
        )

    def door(self, name, parent, place_id, spawn_id, verb, pos, yaw=0.0, size=(2.4, 2.2, 1.6)) -> None:
        """A doorway the player can use (scenes/places/Door.tscn): its verb,
        where it leads and which spawn point to land on are data on the node."""
        self.nodes.append(
            f'[node name="{name}" parent="{parent}" instance=ExtResource("door")]\n'
            f"transform = {xf(pos, yaw)}\n"
            f'place_id = "{place_id}"\nspawn_id = "{spawn_id}"\nverb_id = "{verb}"\n'
            f"reach = Vector3({size[0]:g}, {size[1]:g}, {size[2]:g})\n\n"
        )

    def spawn(self, name, parent, spawn_id, pos, yaw=0.0) -> None:
        """Where the player stands on arriving through the named door."""
        self.nodes.append(
            f'[node name="{name}" type="Marker3D" parent="{parent}"]\n'
            f"transform = {xf(pos, yaw)}\n"
            f'script = ExtResource("spawn")\nspawn_id = "{spawn_id}"\n\n'
        )


def load_parts(folder) -> list:
    """Imports every tools/<folder>/*.py in name order. A part is a module
    that adds to a generated scene (or sound or texture set) without editing
    the generator: one feature, one file, no registration line to collide
    on. Returns the modules."""
    import importlib.util
    from pathlib import Path as _Path

    modules = []
    base = _Path(__file__).resolve().parent / folder
    if not base.is_dir():
        return modules
    for path in sorted(base.glob("*.py")):
        if path.name.startswith("_"):
            continue
        spec = importlib.util.spec_from_file_location(f"{folder}.{path.stem}", path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        modules.append(module)
    return modules
