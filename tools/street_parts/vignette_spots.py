"""The three fixed spots where a dawn vignette's stranger stands (GDD §16a).

Each is scenes/quest/VignetteSpot.tscn with its letter; which stranger stands
there on a given day is decided at run time from data/vignettes/ and the
journey (scripts/core/vignettes.gd, scripts/quest/vignette_spot.gd). Nothing
here is a vignette: the spots are empty when nothing is pending.
"""

import math

EXT = '[ext_resource type="PackedScene" path="res://scenes/quest/VignetteSpot.tscn" id="vignette_spot"]\n'

# letter -> (position, yaw); yaw 0 faces north (-Z), as every body here does.
SPOTS = {
    # The pavement between the fountain and the road, facing the fountain.
    # East of the wet footprints (Tells) by more than both reaches, on the
    # south pavement; the Home door's reach ends 0.4 m short of its Talk.
    "a": ((5.0, 0.16, 9.6), 0.0),
    # The corner by the crossing, facing the light.
    "b": ((26, 0.16, 21), math.atan2(-(30 - 26), -(16 - 21))),
    # Along the padlocked fence, facing it.
    "c": ((-36, 0, 12), 0.0),
}


def build(b) -> None:
    from scenegen import xf

    b.group("Vignettes")
    for letter, (pos, yaw) in SPOTS.items():
        b.nodes.append(
            f'[node name="VignetteSpot{letter.upper()}" parent="Vignettes" instance=ExtResource("vignette_spot")]\n'
            "unique_name_in_owner = true\n"
            f"transform = {xf(pos, yaw)}\n"
            f'spot = "{letter}"\n\n'
        )
