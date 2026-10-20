"""The chai stall's front: Amma at the hatch with a line or two, her kettle and
cups on the shelf, the steam, the sign, and the chant that leaks from the
shrine room behind the back door when someone hums there.

GDD §3 Act 3 "Arrival" (a chai stall), §5 ("the shrine room is tucked behind
the chai stall, found by following Tulu"; "leaks a faint drone of Madhuri's
chanting"), §7 micro-interaction "Hum near the shrine". The stall itself
(body, roof, hatch, shelf, back door) is in tools/gen_street.py; this dresses
its front. The shrine interior and the door that opens are another feature's.

PLACEHOLDER: Amma's body is the shared Kenney rig (GDD §10 painted
characters); kettle and cups are primitives (GDD §10 painted props).
"""

import math

from scenegen import xf

# gen_street.py: Body (13, 1.4, -9) is 5 x 2.8 x 4, so the front face is
# z = -7; the shelf top is y = 0.95 across x 11.2..14.8; the back door is on
# the north face at z = -11.05, where Tulu's last waypoint ends.
X, FRONT_Z, SHELF_Y, BACK_Z = 13.0, -7.0, 0.95, -11.05
SOUTH = math.pi  # a body yaw facing +Z, toward the fountain

EXT = (
    '[ext_resource type="PackedScene" path="res://scenes/npc/Shopkeeper.tscn" id="chai_keeper"]\n'
    '[ext_resource type="Script" path="res://scripts/street/steam.gd" id="chai_steam"]\n'
    '[ext_resource type="AudioStream" path="res://assets/audio/chant_outside.ogg" id="chai_chant"]\n'
)


def build(b) -> None:
    b.group("ChaiFront")
    # Amma, beside the shelf at the hatch's west end, facing the street. Her
    # lines live in data/dialogue/en.json (chai_greet); the order is data here.
    b.nodes.append(
        '[node name="Amma" parent="ChaiFront" instance=ExtResource("chai_keeper")]\n'
        "unique_name_in_owner = true\n"
        f"transform = {xf((10.9, 0, -6.4), SOUTH)}\n"
        'entry_lines = PackedStringArray("chai_greet")\n\n'
        '[node name="Figure" parent="ChaiFront/Amma" index="1"]\n'
        'skin = ExtResource("skin_humanFemaleA")\n\n'
    )
    # The kettle on the shelf: body, lid, handle, a spout laid along X.
    kx, kz = X + 0.9, FRONT_Z + 0.2
    b.cyl("Kettle", "ChaiFront", (kx, SHELF_Y + 0.16, kz), 0.17, 0.32, "rust_metal")
    b.cyl("KettleLid", "ChaiFront", (kx, SHELF_Y + 0.35, kz), 0.08, 0.06, "tyre")
    b.solid("KettleHandle", "ChaiFront", (kx, SHELF_Y + 0.42, kz), (0.22, 0.03, 0.03), "tyre", collide=False)
    b.cyl("KettleSpout", "ChaiFront", (kx + 0.26, SHELF_Y + 0.26, kz), 0.025, 0.2, "rust_metal", lay=True)
    # Cups: two rows of small glasses west of the kettle, one draw call.
    cups = [((X - 1.1 + i * 0.28, SHELF_Y + 0.035, kz + dz), 0.0, (0.07, 0.07, 0.07))
            for i in range(4) for dz in (-0.1, 0.1)]
    b.multimesh("Cups", "ChaiFront", "CylinderMesh_unit", "plaster_white", cups, shadows=False)
    # Steam off the kettle; scripts/street/steam.gd scales and fades it.
    b.nodes.append(
        '[node name="Steam" type="MeshInstance3D" parent="ChaiFront"]\n'
        f"transform = {xf((kx, SHELF_Y + 0.62, kz), 0.0, (0.16, 0.3, 0.16))}\n"
        'mesh = SubResource("CylinderMesh_unit")\n'
        "cast_shadow = 0\n"
        'script = ExtResource("chai_steam")\n\n'
    )
    # The sign, in front of the stall's sign board, read from the street.
    b.label("ChaiSign", "ChaiFront", "sign.chai", (X, 3.5, FRONT_Z + 0.18), 0.0, size=56)
    # The chant from the shrine room, at the back door: silent until a hum at
    # the door stirs it (scripts/npc/tulu.gd), faint beyond a few metres.
    # PLACEHOLDER sound: tools/audio_parts/chant_outside.py names its replacement.
    b.nodes.append(
        '[node name="ChantOutside" type="AudioStreamPlayer3D" parent="ChaiFront" groups=["chant_outside"]]\n'
        f"transform = {xf((X, 1.3, BACK_Z - 0.3))}\n"
        'stream = ExtResource("chai_chant")\n'
        "volume_db = -6.0\nunit_size = 3.0\nmax_distance = 14.0\n\n"
    )
