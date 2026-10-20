"""The hall's front, and Dhanpal in front of it (GDD §7 "Main quest": giver
Dhanpal, at the hall, on arrival; §4 Dhanpal; §8 Scene C).

The hall is the last south flat (gen_street.py `south[-1]`, at x 48, z 30,
its street face at z ≈ 24.9). This part gives that face a front: a wide low
step at the pavement's road edge, two pillars on it, a fascia across them
carrying the sign, a roof back to the flat, and a dark doorway in the face
between two of the flat's windows. The pavement's walking loop (Ambience,
z 23 and 24.4) passes under the roof between the pillars and the door: a
colonnade people walk through, as they do.

Dhanpal stands on the step facing the road. PLACEHOLDER: primitives in the
street's own textures, replaced by the hall of GDD §5 "Hollow Vale".
"""

from __future__ import annotations

import math

from scenegen import Builder, xf

EXT = '[ext_resource type="PackedScene" path="res://scenes/npc/Dhanpal.tscn" id="dhanpal"]\n'

# The portico's centre line and the flat's face it leans on (gen_street.py:
# Flat11 at x 48, z 30, 12 x 10 m; face_z = z - d / 2 - 0.06).
HALL_X = 46.0
FACE_Z = 24.94
# The kerb pavement's top (gen_street.py KerbEW23) and the step above it.
PAVEMENT_Y = 0.16
STEP_HEIGHT = 0.14
STEP_TOP = PAVEMENT_Y + STEP_HEIGHT
# The step hugs the pavement's road edge (kerb from z 21.5) and ends before
# the pedestrians' line at z 23.
STEP_Z, STEP_DEPTH, STEP_WIDTH = 22.1, 1.0, 7.4
PILLAR_Z, PILLAR_HALF_SPAN, PILLAR_R = 22.2, 2.3, 0.28
ROOF_Y = 4.6
# The doorway sits between the flat's windows at x 44.5 and 48 (1.5 m wide
# each), so it is 1.8 m wide, centred a little east of the portico.
DOOR_X, DOOR_W, DOOR_H = 46.25, 1.8, 2.6
# Dhanpal, on the step, a little west of the doorway, facing the road (-Z).
DHANPAL_POS = (45.2, STEP_TOP, 22.05)


def build(b: Builder) -> None:
    b.group("Hall")
    # The wide step, flush with the kerb's road edge.
    b.solid("Step", "Hall", (HALL_X, PAVEMENT_Y + STEP_HEIGHT / 2, STEP_Z),
            (STEP_WIDTH, STEP_HEIGHT, STEP_DEPTH), "ph_concrete")
    # Two pillars on the step, up to the fascia.
    pillar_h = ROOF_Y - 0.5 - STEP_TOP
    for side, x in (("W", HALL_X - PILLAR_HALF_SPAN), ("E", HALL_X + PILLAR_HALF_SPAN)):
        b.cyl(f"Pillar{side}", "Hall", (x, STEP_TOP + pillar_h / 2, PILLAR_Z), PILLAR_R, pillar_h, "plaster_white")
        b.cyl(f"Pillar{side}Base", "Hall", (x, STEP_TOP + 0.12, PILLAR_Z), PILLAR_R + 0.1, 0.24, "concrete_dust")
        b.cyl(f"Pillar{side}Cap", "Hall", (x, STEP_TOP + pillar_h - 0.08, PILLAR_Z), PILLAR_R + 0.1, 0.16, "concrete_dust")
    b.collider("PillarBody", "Hall", (PILLAR_R * 2 + 0.1, pillar_h, PILLAR_R * 2 + 0.1),
               [((HALL_X - PILLAR_HALF_SPAN, STEP_TOP + pillar_h / 2, PILLAR_Z), 0.0),
                ((HALL_X + PILLAR_HALF_SPAN, STEP_TOP + pillar_h / 2, PILLAR_Z), 0.0)])
    # The fascia across the pillars, the sign on its street side, the roof
    # back to the flat's face.
    b.solid("Fascia", "Hall", (HALL_X, ROOF_Y - 0.25, PILLAR_Z), (STEP_WIDTH - 0.6, 0.5, 0.5), "timber", collide=False)
    b.label("Sign", "Hall", "sign.hall", (HALL_X, ROOF_Y - 0.25, PILLAR_Z - 0.26), math.pi, size=64)
    roof_depth = FACE_Z - (PILLAR_Z - 0.25)
    b.solid("Roof", "Hall", (HALL_X, ROOF_Y + 0.08, PILLAR_Z - 0.25 + roof_depth / 2),
            (STEP_WIDTH - 0.6, 0.16, roof_depth), "ph_corrugated", collide=False)
    # The doorway: a dark recess in the face, a timber frame round it.
    b.solid("Doorway", "Hall", (DOOR_X, DOOR_H / 2, FACE_Z - 0.06), (DOOR_W, DOOR_H, 0.14), "tyre", collide=False)
    for side, x in (("L", DOOR_X - DOOR_W / 2 - 0.02), ("R", DOOR_X + DOOR_W / 2 + 0.02)):
        b.solid(f"DoorFrame{side}", "Hall", (x, DOOR_H / 2 + 0.05, FACE_Z - 0.08), (0.14, DOOR_H + 0.1, 0.18), "timber", collide=False)
    b.solid("DoorLintel", "Hall", (DOOR_X, DOOR_H + 0.12, FACE_Z - 0.08), (DOOR_W + 0.1, 0.14, 0.18), "timber", collide=False)
    # Dhanpal (scenes/npc/Dhanpal.tscn), on the step, facing the road.
    b.nodes.append(
        '[node name="Dhanpal" parent="Hall" instance=ExtResource("dhanpal")]\n'
        "unique_name_in_owner = true\n"
        f"transform = {xf(DHANPAL_POS, 0.0)}\n\n"
    )
