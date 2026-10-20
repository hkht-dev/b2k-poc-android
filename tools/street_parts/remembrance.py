"""Act 4, Remembrance: *Hum here* on the fountain steps (GDD §3 Act 4, §3a Act 4).

scenes/quest/Remembrance.tscn, placed on the south-east corner step of the
fountain, where the pavement steps down toward the lip. The verb appears once
the tower has set `played_for_others` or `kept_veena`; what the world does in
answer is data on that scene (scripts/quest/remembrance.gd).
"""

from scenegen import xf

EXT = '[ext_resource type="PackedScene" path="res://scenes/quest/Remembrance.tscn" id="remembrance"]\n'

# The step round the lip is 0.15 m below the pavement (gen_street.py STEP_Y);
# its south-east corner is the one notch the lip's torus leaves walkable.
STEP_Y = -0.15
CORNER = (5.55, STEP_Y, 5.55)


def build(b) -> None:
    b.nodes.append(
        '[node name="Remembrance" parent="Fountain" instance=ExtResource("remembrance")]\n'
        "unique_name_in_owner = true\n"
        f"transform = {xf(CORNER)}\n\n"
    )
