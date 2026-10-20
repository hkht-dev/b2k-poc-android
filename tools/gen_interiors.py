#!/usr/bin/env python3
"""Generate the insides of the shops: scenes/places/Showroom.tscn and Store.tscn.

Owner expansion 2026-10-20 (docs/DECISIONS.md "The world grows"): a shop on
the street can be walked into. Each inside is its own place (data/places.json)
built the way the street is, from the same textures and CC0 models through
tools/scenegen.py, with the same player, camera and HUD. The door back out
and the spawn point just inside carry the same id as the door on the street.

    python3 tools/gen_interiors.py           # writes scenes/places/*.tscn
    python3 tools/gen_interiors.py --check   # fails if a committed scene is stale

Layout: X east, Z south, Y up; the room is centred on the origin, its door
in the north wall (the street side), the floor top at y = 0.
"""

from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))
from scenegen import (  # noqa: E402
    COMMON_EXT, MESHES, Builder, ext_materials, ext_models, ext_skins, finish, load_parts, xf,
)

OUT_DIR = ROOT / "scenes" / "places"
WALL = 0.3
HEIGHT = 3.4
SOUTH = math.pi  # a body yaw facing +Z (into the room from the door)
NORTH = 0.0


def room(b: Builder, w: float, d: float, floor_mat: str, wall_mat: str, spawn_id: str) -> None:
    """Floor, four walls, a ceiling, the doorway in the north wall, the door
    back to the street and the spawn point just inside it."""
    b.group("Room")
    b.solid("Floor", "Room", (0, -0.1, 0), (w, 0.2, d), floor_mat)
    b.solid("Ceiling", "Room", (0, HEIGHT + 0.1, 0), (w + 0.6, 0.2, d + 0.6), "plaster_white", collide=False)
    b.solid("WallNorth", "Room", (0, HEIGHT / 2, -d / 2 - WALL / 2), (w + WALL * 2, HEIGHT, WALL), wall_mat)
    b.solid("WallSouth", "Room", (0, HEIGHT / 2, d / 2 + WALL / 2), (w + WALL * 2, HEIGHT, WALL), wall_mat)
    b.solid("WallWest", "Room", (-w / 2 - WALL / 2, HEIGHT / 2, 0), (WALL, HEIGHT, d), wall_mat)
    b.solid("WallEast", "Room", (w / 2 + WALL / 2, HEIGHT / 2, 0), (WALL, HEIGHT, d), wall_mat)
    # The street's doorway, seen from inside: a dark recess, a timber frame,
    # a window either side of it so the room is not a box.
    face = -d / 2 + 0.01
    b.solid("Doorway", "Room", (0, 1.2, face - 0.08), (1.5, 2.4, 0.16), "tyre", collide=False)
    b.solid("FrameL", "Room", (-0.85, 1.25, face), (0.14, 2.5, 0.2), "timber", collide=False)
    b.solid("FrameR", "Room", (0.85, 1.25, face), (0.14, 2.5, 0.2), "timber", collide=False)
    b.solid("Lintel", "Room", (0, 2.52, face), (1.9, 0.14, 0.2), "timber", collide=False)
    for side, x in (("W", -w / 4 - 0.4), ("E", w / 4 + 0.4)):
        b.solid(f"Window{side}", "Room", (x, 1.6, face - 0.06), (3.0, 1.8, 0.12), "tyre", collide=False)
        b.solid(f"Sill{side}", "Room", (x, 0.66, face + 0.1), (3.3, 0.1, 0.4), "timber", collide=False)
    b.door("DoorOut", "Room", "street", spawn_id, "verb.leave", (0, 0, -d / 2 + 0.9), size=(2.6, 2.2, 1.7))
    b.spawn("SpawnIn", "Room", spawn_id, (0, 0, -d / 2 + 1.9), SOUTH)


def lights(b: Builder, spots: list[tuple[float, float]], colour=(1.0, 0.93, 0.8)) -> None:
    b.group("Lights")
    r, g, bl = colour
    for i, (x, z) in enumerate(spots):
        b.nodes.append(
            f'[node name="Lamp{i}" type="OmniLight3D" parent="Lights"]\n'
            f"transform = {xf((x, HEIGHT - 0.3, z))}\n"
            f"light_color = Color({r:g}, {g:g}, {bl:g}, 1)\nlight_energy = 1.6\n"
            f"omni_range = 9.0\nomni_attenuation = 1.2\nshadow_enabled = false\n\n"
        )
        b.cyl(f"Shade{i}", "Lights", (x, HEIGHT - 0.22, z), 0.28, 0.16, "rust_metal")


def keeper(b: Builder, name: str, skin: str, line: str, pos, yaw: float) -> None:
    b.nodes.append(
        f'[node name="{name}" parent="." instance=ExtResource("keeper")]\n'
        "unique_name_in_owner = true\n"
        f"transform = {xf(pos, yaw)}\n"
        f'entry_lines = PackedStringArray("{line}")\n\n'
        f'[node name="Figure" parent="{name}" index="1"]\n'
        f'skin = ExtResource("skin_{skin}")\n\n'
    )


# --------------------------------------------------------------- the showroom

def showroom() -> str:
    b = Builder()
    W, D = 13.0, 9.0
    room(b, W, D, "timber", "plaster_cream", "showroom_door")
    lights(b, [(-3.5, -1.5), (3.5, -1.5), (1.5, 2.5)])
    b.group("Fittings")
    # The counter along the south wall, west of centre so the mirror's corner
    # stays clear; the tailor behind it.
    b.solid("Counter", "Fittings", (1.0, 0.5, 3.4), (4.0, 1.0, 0.7), "timber")
    b.solid("CounterTop", "Fittings", (1.0, 1.02, 3.4), (4.2, 0.06, 0.9), "plaster_white", collide=False)
    b.label("SignInside", "Fittings", "sign.showroom_inside", (1.0, 2.5, D / 2 - 0.05), NORTH, size=56)
    keeper(b, "Tailor", "survivorMaleB", "tailor_greet", (1.0, 0, 4.0), NORTH)
    # Two rails of clothes along the west wall, in the street's own cloth.
    garments = []
    for row, z in enumerate((-2.6, 0.4)):
        b.cyl(f"Rail{row}", "Fittings", (-4.9, 1.75, z), 0.025, 2.8, "rust_metal", lay=True)
        for i in range(7):
            x = -6.15 + i * 0.42
            garments.append(((x, 1.25, z), 0.0, (0.34, 0.95, 0.07)))
        b.solid(f"RailPostL{row}", "Fittings", (-6.2, 0.9, z), (0.06, 1.8, 0.06), "rust_metal", collide=False)
        b.solid(f"RailPostR{row}", "Fittings", (-3.6, 0.9, z), (0.06, 1.8, 0.06), "rust_metal", collide=False)
    b.multimesh("GarmentsCoat", "Fittings", "BoxMesh_unit", "coat", garments[0::2], shadows=False)
    b.multimesh("GarmentsPale", "Fittings", "BoxMesh_unit", "cloth_pale", garments[1::2], shadows=False)
    b.collider("RailBody", "Fittings", (2.9, 1.8, 0.5), [((-4.9, 0.9, -2.6), 0.0), ((-4.9, 0.9, 0.4), 0.0)])
    # Three mannequins on round plinths by the east wall, dressed differently.
    mannequins = (("skaterFemaleA", -3.2), ("criminalMaleA", -1.3), ("survivorFemaleA", 0.6))
    for i, (skin, z) in enumerate(mannequins):
        b.cyl(f"Plinth{i}", "Fittings", (4.8, 0.1, z), 0.55, 0.2, "plaster_white")
        b.figure(f"Mannequin{i}", "Fittings", skin, (4.8, 0.2, z), yaw=-math.pi / 2)
    b.collider("PlinthBody", "Fittings", (1.1, 1.0, 1.1), [((4.8, 0.5, z), 0.0) for _, z in mannequins])
    # The long mirror on the east wall; a dark pane with a timber frame.
    mirror_z = 3.2
    b.solid("MirrorFrame", "Fittings", (W / 2 - 0.06, 1.3, mirror_z), (0.1, 2.4, 1.8), "timber", collide=False)
    b.solid("Mirror", "Fittings", (W / 2 - 0.1, 1.3, mirror_z), (0.04, 2.2, 1.6), "tyre", collide=False)
    # Before the mirror, the fitting dais: a round plinth low enough to step
    # onto (0.2 m, under the player's step height), carrying the Try-on stand
    # (scenes/quest/TryOnStand.tscn) whose verb opens the wardrobe. Owner
    # request 2026-10-20: "go to showroom and try on different clothes".
    dais = (4.3, 0.1, mirror_z)
    b.cyl("Dais", "Fittings", dais, 0.6, 0.2, "plaster_white")
    b.collider("DaisBody", "Fittings", (1.2, 0.2, 1.2), [(dais, 0.0)])
    b.nodes.append(
        '[node name="TryOnStand" parent="Fittings" instance=ExtResource("try_on")]\n'
        "unique_name_in_owner = true\n"
        f"transform = {xf((dais[0], 0.2, dais[2]), -math.pi / 2)}\n\n"
    )
    # A low table with folded cloth, mid-room.
    b.solid("Table", "Fittings", (0, 0.4, 0.8), (2.0, 0.08, 1.0), "timber")
    b.solid("TableLegs", "Fittings", (0, 0.2, 0.8), (1.8, 0.4, 0.8), "timber")
    for i, (dx, dz, mat) in enumerate(((-0.5, -0.2, "cloth_pale"), (0.4, 0.1, "coat"), (0.0, 0.3, "canopy"))):
        b.solid(f"Folded{i}", "Fittings", (dx, 0.5, 0.8 + dz), (0.5, 0.12, 0.4), mat, collide=False)
    try_on_ext = '[ext_resource type="PackedScene" path="res://scenes/quest/TryOnStand.tscn" id="try_on"]\n'
    return assemble(b, "Showroom", "showroom", (0.42, 0.36, 0.3), extra_ext=try_on_ext)


# ------------------------------------------------------------------ the store

def store() -> str:
    b = Builder()
    W, D = 11.0, 9.0
    room(b, W, D, "concrete_dust", "plaster_white", "store_door")
    lights(b, [(-2.5, -1.5), (2.5, -1.5), (0, 2.6)], colour=(0.95, 0.97, 1.0))
    b.group("Fittings")
    b.solid("Counter", "Fittings", (-2.5, 0.5, 3.4), (4.0, 1.0, 0.7), "timber")
    b.solid("CounterTop", "Fittings", (-2.5, 1.02, 3.4), (4.2, 0.06, 0.9), "plaster_white", collide=False)
    b.label("SignInside", "Fittings", "sign.store_inside", (-2.5, 2.5, D / 2 - 0.05), NORTH, size=56)
    keeper(b, "Storekeeper", "survivorFemaleA", "storekeeper_greet", (-2.5, 0, 4.0), NORTH)
    # Shelf units down both long walls, stocked with crates and cans.
    crates, cans, boards = [], [], []
    for side, x in (("W", -W / 2 + 0.45), ("E", W / 2 - 0.45)):
        for unit, z in enumerate((-2.6, 0.0, 2.6)):
            b.solid(f"Shelf{side}{unit}", "Fittings", (x, 1.0, z), (0.9, 2.0, 2.4), "timber")
            for level, y in enumerate((0.45, 1.05, 1.65)):
                boards.append(((x, y, z), 0.0, (0.96, 0.05, 2.5)))
                for k in range(3):
                    cz = z - 0.8 + k * 0.8
                    if (unit + level + k) % 3 == 0:
                        crates.append(((x, y + 0.03, cz), 0.3 * k, (1.3, 1.3, 1.3)))
                    else:
                        cans.append(((x - 0.12 + 0.12 * (k % 2), y + 0.03, cz), 0.9 * k, (1.3, 1.3, 1.3)))
    b.multimesh("ShelfBoards", "Fittings", "BoxMesh_unit", "plaster_white", boards, shadows=False)
    b.batch("ShelfCrates", "Fittings", "crate", crates, shadows=False)
    b.batch("ShelfCans", "Fittings", "can", cans, shadows=False)
    # A gondola of crates mid-room the player walks round.
    b.batch("FloorCrates", "Fittings", "crate",
            [((0.3, 0, -0.6), 0.2, (1.5,) * 3), ((0.3, 0.39, -0.6), 0.6, (1.5,) * 3),
             ((-0.5, 0, -0.2), 1.1, (1.5,) * 3), ((0.4, 0, 0.3), 0.4, (1.5,) * 3)])
    b.collider("FloorCrateBody", "Fittings", (2.0, 1.0, 1.6), [((0, 0.5, -0.2), 0.0)])
    # Sacks by the counter's end: cloth boxes.
    for i, (dx, dz) in enumerate(((0.6, 3.3), (1.2, 3.5), (0.9, 2.8))):
        b.solid(f"Sack{i}", "Fittings", (dx, 0.3, dz), (0.6, 0.6, 0.5), "cloth_pale", yaw=0.4 * i, collide=False)
    b.collider("SackBody", "Fittings", (1.4, 0.8, 1.2), [((0.9, 0.4, 3.2), 0.0)])
    return assemble(b, "Store", "store", (0.36, 0.38, 0.42))


# ------------------------------------------------------------------ assembly

def assemble(b: Builder, name: str, place_id: str, bg: tuple, extra_ext: str = "") -> str:
    r, g, bl = bg
    header = (
        "[gd_scene load_steps=STEPS format=3]\n\n"
        f"; {name}, inside. GENERATED by tools/gen_interiors.py; edit that, not this.\n"
        "; Owner expansion 2026-10-20 (docs/DECISIONS.md \"The world grows\").\n"
        ";\n"
        "; PLACEHOLDER: primitives with the street's procedural textures and CC0\n"
        "; stand-in models (docs/RIGHTS_REGISTER.md). Replaced by the painted\n"
        "; stylized 3D of GDD §10. Palette: GDD §10, Hollow Vale row.\n\n"
        '[ext_resource type="Script" path="res://scripts/places/place.gd" id="1_place"]\n'
        '[ext_resource type="PackedScene" path="res://scenes/npc/Shopkeeper.tscn" id="keeper"]\n'
        + extra_ext + COMMON_EXT + ext_skins() + ext_models() + ext_materials() + MESHES
        + f"""[sub_resource type="Environment" id="Environment_inside"]
background_mode = 1
background_color = Color({r:g}, {g:g}, {bl:g}, 1)
ambient_light_source = 2
ambient_light_color = Color(0.82, 0.78, 0.72, 1)
ambient_light_energy = 0.9
tonemap_mode = 2
tonemap_exposure = 1.0

"""
    )
    root = (
        f'[node name="{name}" type="Node3D"]\n'
        'script = ExtResource("1_place")\n'
        f'place_id = "{place_id}"\n\n'
        '[node name="Environment" type="WorldEnvironment" parent="."]\n'
        'environment = SubResource("Environment_inside")\n\n'
    )
    footer = f"""[node name="Player" parent="." instance=ExtResource("4_player")]
unique_name_in_owner = true
transform = {xf((0, 0, -2.5), SOUTH)}

[node name="CameraRig" parent="." instance=ExtResource("5_rig")]
unique_name_in_owner = true
target_path = NodePath("../Player")

[node name="UI" type="CanvasLayer" parent="."]

[node name="TouchControls" parent="UI" instance=ExtResource("6_controls")]
unique_name_in_owner = true
"""
    return finish(header + b.shape_defs() + "".join(b.multimeshes) + root + "".join(b.nodes) + footer)


SCENES = {"Showroom.tscn": showroom, "Store.tscn": store}
# tools/interiors/<name>.py: one more inside each, through `scene()`, which
# returns (file name, scene text) and may use room(), lights(), keeper() and
# assemble() from here (`from gen_interiors import ...`).
for _part in load_parts("interiors"):
    _name, _build = _part.scene_name(), _part.scene
    SCENES[_name] = _build


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    stale = 0
    for filename, build in SCENES.items():
        out = OUT_DIR / filename
        text = build()
        if args.check:
            if not out.exists() or out.read_text() != text:
                print(f"gen_interiors: {out.relative_to(ROOT)} is stale; run tools/gen_interiors.py", file=sys.stderr)
                stale += 1
            continue
        out.write_text(text)
        print(f"gen_interiors: wrote {out.relative_to(ROOT)}")
    if args.check and not stale:
        print("gen_interiors: interiors are current")
    return 1 if stale else 0


if __name__ == "__main__":
    sys.exit(main())
