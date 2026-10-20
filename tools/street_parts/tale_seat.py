"""A seat for a tale on the fountain's step, for development (GDD §3a, §9a).

The tale mechanic (scenes/quest/TaleSeat.tscn, data/tales.json) belongs in
the shrine room beside Madhuri, which another change builds. Until it has a
room, a cushion on the step round the fountain offers *Sit* so the scroll can
be played on the street. The shrine change moves or duplicates this
(docs/DECISIONS.md "Sitting for a tale").
"""

from __future__ import annotations

import math

from scenegen import xf

EXT = '[ext_resource type="PackedScene" path="res://scenes/quest/TaleSeat.tscn" id="tale_seat"]\n'

# The south-east corner of the step round the fountain (gen_street.py
# StepSE), where the step shows between the lip's torus and the pavement.
# docs/DECISIONS.md: (0, -0.15, 6.9) lies inside the lip, so the seat moved
# round to the corner at the same height.
SEAT = (5.4, -0.15, 5.4)
# The sign faces the pavement corner the player arrives from (+X, +Z).
SIGN_YAW = math.pi / 4


def build(b) -> None:
    x, y, z = SEAT
    b.group("TaleSeatSpot")
    # PLACEHOLDER: a flat cylinder in the street's own cloth stands for
    # Madhuri's mat in the shrine room (GDD §4 Madhuri, §9a).
    b.cyl("Cushion", "TaleSeatSpot", (x, y + 0.06, z), 0.45, 0.12, "coat")
    b.nodes.append(
        '[node name="TaleSeat" parent="TaleSeatSpot" instance=ExtResource("tale_seat")]\n'
        "unique_name_in_owner = true\n"
        f"transform = {xf((x, y, z))}\n"
        'tale_id = "puranjana"\n\n'
    )
    b.label("TaleSign", "TaleSeatSpot", "sign.tale_seat", (x, y + 1.35, z), SIGN_YAW, size=40)
