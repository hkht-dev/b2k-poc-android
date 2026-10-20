"""Stray cows: two of the Grove's cows on the north pavement, east of the fountain.

GDD §3a Act 3 ("Walk ahead of two cows and hum to steer them through
traffic") and §16a "Stray cows". The cow itself is scenes/street/Cow.tscn
(scripts/street/cow.gd); this part only says where the two stand, where each
rests once it has arrived, and which event each fires on the fountain's
step. All of it is data on the nodes, none of it in code.

They start at (40, 5) and (42.5, 2.5): on the pavement east of the
north-south road, north of the east-west one, so the shortest path to the
fountain crosses one road, and a hum from the wrong side of the other
crosses two. The second stands 1.5 m off the pedestrian loop's east leg
(x = 44) so nobody is stuck behind it at the start.
"""

from scenegen import xf

EXT = '[ext_resource type="PackedScene" path="res://scenes/street/Cow.tscn" id="cow"]\n'

# (name, home, yaw, rest at the fountain once arrived, event fired there)
COWS = [
    ("Cow0", (40, 0, 5), 1.5708, (8.6, 0, 2.6), "cow_reached_fountain_0"),
    ("Cow1", (42.5, 0, 2.5), 2.3, (8.4, 0, -2.4), "cow_reached_fountain_1"),
]


def build(b) -> None:
    b.group("Cows")
    for name, home, yaw, rest, event in COWS:
        b.nodes.append(
            f'[node name="{name}" parent="Cows" instance=ExtResource("cow")]\n'
            f"transform = {xf(home, yaw)}\n"
            f'reached_event = "{event}"\n'
            f"rest_position = Vector3({rest[0]:g}, {rest[1]:g}, {rest[2]:g})\n\n"
        )
