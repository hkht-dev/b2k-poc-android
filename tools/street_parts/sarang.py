"""Sarang's corner: a crate stool, the instrument with the missing string, a
sign on a post, and Sarang himself (scenes/npc/Sarang.tscn) on the north
ground east of the chai stall, near (20, 0, -9).

GDD §4 Sarang ("thin, nervous, the only one who cares about the music";
"he knows the melody's first bar"); §7 Investigate step 4 and Mediate step
3 (the missing string). Which lines he says and which of them open a lesson
are data on his node below; the lesson itself is data/song.json.

PLACEHOLDER props: primitives and the Poly Haven crate stand in for the
painted stylised props of GDD §10; the instrument is a timber box with three
strings and a gap where the fourth was.
"""

from __future__ import annotations

import math

from scenegen import MAT_ID, Builder, xf

EXT = '[ext_resource type="PackedScene" path="res://scenes/npc/Sarang.tscn" id="sarang"]\n'

AT = (20.0, 0.0, -9.0)
# He faces the fountain the Song was played from, in the yaw convention of
# the NPC scripts (atan2(-dx, -dz) toward a point).
YAW = math.atan2(-(0.0 - AT[0]), -(0.0 - AT[2]))
# Lines tried in order: the first whose requirements hold opens, skipping a
# line while its SKIP_WHEN flag holds (scripts/npc/sarang.gd). The string
# hand-over comes first and goes once given; the thanks are said once.
ENTRY_LINES = [
    "sarang_string", "sarang_thanks", "sarang_after",
    "sarang_greet_tulu", "sarang_greet_shrine", "sarang_greet",
]
SKIP_WHEN = {"sarang_string": "sarang_string_given", "sarang_thanks": "sarang_thanked"}
# The lines that open a lesson, by bar in data/song.json.
LESSONS = {"sarang_lesson": "bar_one", "sarang_lesson_two": "bar_two"}
# The Poly Haven crate is 0.3 x 0.26 x 0.41 m; at this scale, a stool.
CRATE = 1.5
# The sign's words wrap on two lines; this pixel size keeps them on the board.
SIGN_PIXEL = 0.0035
# A mat at his right hand for Prahlada's tale (data/tales.json "prahlada",
# the boy pressed by his teachers; GDD §9a): the one teacher on the Street
# tells it. Its seat scene is tale_seat.py's ext_resource ("tale_seat").
TALE_MAT = (0.4, 2.6)  # (forward, right) in his frame


def _place(forward: float, right: float, up: float = 0.0, origin=AT, yaw: float = YAW):
    """A point in a body's own frame (forward the way it faces, right its
    right hand, up) as a world position."""
    c, s = math.cos(yaw), math.sin(yaw)
    return (origin[0] + c * right - s * forward, origin[1] + up, origin[2] - s * right - c * forward)


def build(b: Builder) -> None:
    b.group("SarangCorner")

    # The crate he sits on, a hand's width behind his hips.
    stool = _place(-0.22, 0.0)
    b.model("Stool", "SarangCorner", "crate", stool, YAW, CRATE)
    b.collider("StoolBody", "SarangCorner", (0.5, 0.4, 0.45), [((stool[0], 0.2, stool[2]), YAW)])

    # The instrument on the ground at his right hand, turned a little toward
    # him (nodes, not batched details: the strings are counted by name).
    # him: a timber body with its long axis to the right, a peg head, a
    # bridge, three strings and the gap where the fourth was.
    inst_yaw = YAW + 0.35
    body = _place(0.75, 0.55, 0.05)
    b.solid("InstrumentBody", "SarangCorner", body, (0.95, 0.1, 0.24), "timber", inst_yaw, collide=False)
    b.solid("InstrumentHead", "SarangCorner", _place(0.0, -0.53, 0.02, body, inst_yaw),
            (0.14, 0.09, 0.26), "timber", inst_yaw, collide=False)
    b.solid("Bridge", "SarangCorner", _place(0.0, 0.3, 0.07, body, inst_yaw),
            (0.02, 0.04, 0.2), "rust_metal", inst_yaw, collide=False)
    for slot, across in enumerate((-0.075, -0.025, 0.025, 0.075)):
        if slot == 2:
            continue  # the missing string (GDD §7 Mediate step 3)
        b.solid(f"String{slot}", "SarangCorner", _place(across, -0.07, 0.06, body, inst_yaw),
                (0.86, 0.006, 0.006), "rust_metal", inst_yaw, collide=False)
    # The fourth string, hidden until the player brings it from Nanda's flat:
    # Sarang shows it when `sarang_string_given` is set.
    b.nodes.append(
        '[node name="StringMended" type="MeshInstance3D" parent="SarangCorner"]\n'
        f"transform = {xf(_place(0.025, -0.07, 0.06, body, inst_yaw), inst_yaw, (0.86, 0.006, 0.006))}\n"
        "visible = false\n"
        'mesh = SubResource("BoxMesh_unit")\n'
        f'surface_material_override/0 = ExtResource("{MAT_ID["rust_metal"]}")\n\n'
    )

    # A sign on a post behind his right shoulder, its words toward the street.
    post = _place(-0.6, 0.95)
    b.solid("SignPost", "SarangCorner", (post[0], 0.75, post[2]), (0.08, 1.5, 0.08), "timber")
    board = (post[0], 1.38, post[2])
    b.detail("SignBoard", "SarangCorner", board, (1.5, 0.6, 0.05), "sign", YAW)
    b.detail("SignFrame", "SarangCorner", board, (1.56, 0.66, 0.03), "timber", YAW)
    # Like Builder.label, with a smaller pixel size so two short lines fit the
    # board; Label3D's face is +Z, which at YAW - pi is the way he faces.
    front = _place(0.035, 0.0, 0.0, board)
    b.nodes.append(
        '[node name="SarangSign" type="Label3D" parent="SarangCorner"]\n'
        f"transform = {xf(front, YAW - math.pi)}\n"
        'script = ExtResource("label_id")\n'
        'text_id = "sign.sarang_corner"\n'
        f"pixel_size = {SIGN_PIXEL:g}\nfont_size = 44\noutline_size = 8\n"
        "modulate = Color(0.16, 0.12, 0.08, 1)\n"
        "shaded = false\ndouble_sided = false\nno_depth_test = false\n\n"
    )

    # The mat for Prahlada's tale beside him, *Sit* on it.
    mat = _place(*TALE_MAT)
    # PLACEHOLDER: a flat cylinder in the street's cloth stands for a mat
    # (GDD §9a); the seat is scenes/quest/TaleSeat.tscn, the tale is data.
    b.detail_cyl("TaleMat", "SarangCorner", (mat[0], 0.03, mat[2]), 0.5, 0.06, "cloth_pale")
    b.nodes.append(
        '[node name="PrahladaSeat" parent="SarangCorner" instance=ExtResource("tale_seat")]\n'
        f"transform = {xf((mat[0], 0.0, mat[2]))}\n"
        'tale_id = "prahlada"\n\n'
    )

    # Sarang, with his lines, his lessons and the string as data on the node.
    lines = ", ".join(f'"{line}"' for line in ENTRY_LINES)
    skips = ",\n".join(f'"{line}": "{flag}"' for line, flag in SKIP_WHEN.items())
    lessons = ",\n".join(f'"{line}": "{bar}"' for line, bar in LESSONS.items())
    b.nodes.append(
        '[node name="Sarang" parent="SarangCorner" instance=ExtResource("sarang")]\n'
        "unique_name_in_owner = true\n"
        f"transform = {xf(AT, YAW)}\n"
        f"entry_lines = PackedStringArray({lines})\n"
        f"skip_when = {{\n{skips}\n}}\n"
        f"lessons = {{\n{lessons}\n}}\n"
        'mended_string = NodePath("../StringMended")\n\n'
    )
