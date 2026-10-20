"""Three of the tower's competitors, waiting out the night on the Street.

GDD §4 (Rukma, Bhima Lal, Old Nanda) and §7, the main quest table: the
Compete and Mediate steps that happen on the Street before the dawn climb.
Each is an instance of scenes/npc/Shopkeeper.tscn with their own skin and
`entry_lines`; what they say, which cards they offer and every flag a card
sets live in data/dialogue, never here. Sarang belongs to the music and
Dhanpal to the hall: neither is placed by this part.

- Rukma, asleep on the bus stop bench, facing the road (GDD §7 Compete:
  "take it from her bag while she sleeps at the bus stop, or trade the
  shopkeeper's water for it"; Mediate: "ask why she needs to win").
- Bhima Lal, the strong one, waiting on Gopal's shop for his daughter's
  medicine (Mediate: "get medicine from the shopkeeper", which The Dry
  Fountain's give path supplies).
- Old Nanda at his own door at the foot of the tower block, where the two
  alleys were: a plain door with his name over it and a *Look* that answers
  with one thought (scripts/quest/look_line.gd). He knows the back stairs.

PLACEHOLDER: the shared rigged body with Kenney skins for all three (GDD §4
"Licensed base" for each); the library's Sitting_Idle stands in for Rukma
asleep until a sleeping clip replaces it.
"""

from __future__ import annotations

import math

from scenegen import Builder, xf

EXT = (
    '[ext_resource type="PackedScene" path="res://scenes/npc/Shopkeeper.tscn" id="competitor"]\n'
    '[ext_resource type="Script" path="res://scripts/quest/look_line.gd" id="look_line"]\n'
)

GROUP = "Competitors"

# The bench is BENCHES[0] in gen_street.py: 4.35 m along X at z = 21, its seat
# about 0.45 m above the kerb (y 0.16). The rig keeps only rotation tracks,
# so a sitting clip leaves the hips where the body's rest pose has them:
# 0.59 m up (measured on scenes/characters/Character.tscn at 1.75 m; Kenney's
# body is short in the leg). The figure's origin goes that far below the seat
# for the hips to meet it.
BENCH_SEAT_Y = 0.61
HIP_HEIGHT = 0.59
RUKMA_POS = (7.3, BENCH_SEAT_Y - HIP_HEIGHT, 21.0)  # the bench's west end; the Counting Man has the east
# Pavement by the shop's east end, looking across at the dry fountain he is
# waiting on; his Talk reaches no part of the can stack's Pick up box.
BHIMA_POS = (-7.6, 0.0, 6.0)
BHIMA_YAW = -1.2
BHIMA_HEIGHT = 1.95  # the gentle giant; everyone else stands 1.75
# The tower block's south face is at z = -18.5 (gen_street.py "Tower").
TOWER_FACE_Z = -18.5
DOOR_X = -29.0
NANDA_POS = (-27.3, 0.0, -17.4)

# name, skin, position, yaw (0 faces -Z, north), entry lines in the order
# *Talk* tries them (first whose `requires` hold opens), figure overrides.
COMPETITORS = [
    (
        "Rukma", "skaterFemaleA", RUKMA_POS, 0.0,
        ["rukma_after_key", "rukma_after_trade", "rukma_greet_can", "rukma_greet"],
        'idle_animation = "Sitting_Idle"\nwalk_animation = "Sitting_Idle"\nrun_animation = "Sitting_Idle"\n',
    ),
    (
        "BhimaLal", "survivorMaleB", BHIMA_POS, BHIMA_YAW,
        ["bhima_thanks", "bhima_waiting", "bhima_greet"],
        f"height = {BHIMA_HEIGHT:g}\n",
    ),
    (
        "Nanda", "humanMaleA", NANDA_POS, math.pi,
        ["nanda_after_shortcut", "nanda_greet_contest", "nanda_after_listen", "nanda_greet"],
        "",
    ),
]


def competitor(b: Builder, name: str, skin: str, pos, yaw: float, lines: list[str], figure: str) -> None:
    quoted = ", ".join(f'"{line}"' for line in lines)
    b.nodes.append(
        f'[node name="{name}" parent="{GROUP}" instance=ExtResource("competitor")]\n'
        "unique_name_in_owner = true\n"
        f"transform = {xf(pos, yaw)}\n"
        f"entry_lines = PackedStringArray({quoted})\n\n"
        f'[node name="Figure" parent="{GROUP}/{name}" index="1"]\n'
        f'skin = ExtResource("skin_{skin}")\n{figure}\n'
    )


def nanda_door(b: Builder) -> None:
    """A plain door in the tower block's south face, a step, his name over
    it, and a *Look* in front that opens one line (GDD §7
    micro-interactions: no giver, no reward). Not a Door: it leads nowhere
    in this slice."""
    face = TOWER_FACE_Z
    b.solid("NandaDoorFrame", GROUP, (DOOR_X, 1.15, face + 0.04), (1.4, 2.3, 0.08), "rust_metal", collide=False)
    b.solid("NandaDoor", GROUP, (DOOR_X, 1.1, face + 0.07), (1.1, 2.2, 0.14), "timber", collide=False)
    b.solid("NandaStep", GROUP, (DOOR_X, 0.08, face + 0.4), (1.6, 0.16, 0.7), "ph_concrete")
    b.label("NandaSign", GROUP, "sign.nanda", (DOOR_X, 2.6, face + 0.12), 0.0, size=40)
    b.nodes.append(
        f'[node name="NandaDoorLook" type="Area3D" parent="{GROUP}"]\n'
        "unique_name_in_owner = true\n"
        f"transform = {xf((DOOR_X, 0.0, face + 0.9))}\n"
        'script = ExtResource("look_line")\n'
        'verb_id = "verb.look"\n'
        'line_id = "nanda_door_look"\n\n'
        f'[node name="Shape" type="CollisionShape3D" parent="{GROUP}/NandaDoorLook"]\n'
        f"transform = {xf((0, 1.1, 0))}\n"
        f'shape = SubResource("{b.shape_id((1.8, 2.2, 1.6))}")\n\n'
    )


def build(b: Builder) -> None:
    b.group(GROUP)
    for name, skin, pos, yaw, lines, figure in COMPETITORS:
        competitor(b, name, skin, pos, yaw, lines, figure)
    nanda_door(b)
