"""The four Glimpse points beyond the traffic light (GDD §6 "Glimpses").

Five fixed points. The traffic light's is placed by gen_street.py with the
light itself (it is the one Tulu looks up at); the other four are here, each
an instance of scenes/quest/Glimpse.tscn whose condition, pose, what it leaves
and where are data on the node. Conditions are flags other features set
(`heard_tulu` is P3's Listen; `rukma_heard`, `rukma_key_taken`, `garden_open`
and `saw_shrine` belong to the stairwell, the garden and the shrine) and never
a timer. Nothing counts them, rewards them or requires them.
"""

from __future__ import annotations

import math

from scenegen import xf

EXT = '[ext_resource type="PackedScene" path="res://scenes/quest/Glimpse.tscn" id="glimpse"]\n'

# Where the player looks from: the fountain. Each figure faces it.
FOUNTAIN = (0.0, 0.0, 0.0)

# name, position, what it faces, condition, point id (seen flag glimpsed_<id>,
# line journey.glimpse.<id>), pose, what it leaves, where that lies (world),
# the pick-up's event, how near (across the ground) ends it.
POINTS = [
    # Standing on the top beam of the billboard frame, 26 m up, seen from the
    # street; the feather lands at the tower's foot on the pavement.
    dict(name="GlimpseTower", pos=(-31, 25.8, -26.3), faces=FOUNTAIN, condition="flag:heard_tulu",
         point="tower", pose="Idle", leaves="feather", lies_at=(-31, 0.0, -17.4),
         event="feather_picked_up_tower", end_distance=10.0),
    # Leaning in the doorway of Nanda's stairwell at the west alley, after the
    # player refused the roof key. The flower lies on the threshold.
    dict(name="GlimpseStairwell", pos=(-29, 0.0, -12), faces=FOUNTAIN,
         condition="flag:rukma_heard and not flag:rukma_key_taken", point="stairwell", pose="Idle",
         leaves="jasmine", lies_at=(-29, 0.0, -12), event="jasmine_picked_up_stairwell",
         end_distance=5.0),
    # The far end of the community garden, once its gate is open; He faces the
    # gate the player comes in by.
    dict(name="GlimpseGarden", pos=(-42, 0.0, 1), faces=(-30.6, 0.0, 7.5), condition="flag:garden_open",
         point="garden", pose="Idle", leaves="jasmine", lies_at=(-42, 0.0, 1),
         event="jasmine_picked_up_garden", end_distance=5.0),
    # Sitting on the chai stall's roof after the shrine behind it has been
    # seen; the feather lies on the pavement before the hatch.
    dict(name="GlimpseChaiStall", pos=(13, 3.1, -9), faces=FOUNTAIN, condition="flag:saw_shrine",
         point="chai_stall", pose="Sitting_Idle", leaves="feather", lies_at=(13.6, 0.0, -6.0),
         event="feather_picked_up_chai_stall", end_distance=4.0),
]


# scenegen.xf writes the basis row by row, which is how Godot reads a
# Transform3D in a scene file; the node it places has basis.x = (c, 0, s) and
# basis.z = (-s, 0, c), so its forward (-Z) is (sin yaw, 0, -cos yaw). Both
# helpers below follow that, and a test pins where the pick-ups land.


def facing(pos, target) -> float:
    """The `xf` yaw that turns a node at `pos` to face `target`."""
    dx, dz = target[0] - pos[0], target[2] - pos[2]
    return math.atan2(dx, -dz)


def local_offset(pos, yaw, world) -> tuple:
    """A world point as an offset in the space of a node at `pos` turned `yaw`."""
    dx, dy, dz = (w - p for w, p in zip(world, pos))
    c, s = math.cos(yaw), math.sin(yaw)
    # `+ 0.0` turns a -0.0 into 0, so the scene text does not read "-0".
    return (c * dx + s * dz + 0.0, dy + 0.0, -s * dx + c * dz + 0.0)


def build(b) -> None:
    b.group("Glimpses")
    for p in POINTS:
        yaw = facing(p["pos"], p["faces"])
        ox, oy, oz = local_offset(p["pos"], yaw, p["lies_at"])
        b.nodes.append(
            f'[node name="{p["name"]}" parent="Glimpses" instance=ExtResource("glimpse")]\n'
            "unique_name_in_owner = true\n"
            f"transform = {xf(p['pos'], yaw)}\n"
            f'trigger_condition = "{p["condition"]}"\n'
            f'seen_flag = "glimpsed_{p["point"]}"\n'
            f'journey_line_id = "journey.glimpse.{p["point"]}"\n'
            f"end_distance = {p['end_distance']:g}\n"
            f'leaves = "{p["leaves"]}"\n'
            f"leaves_offset = Vector3({ox:.4g}, {oy:.4g}, {oz:.4g})\n"
            f'pickup_event = "{p["event"]}"\n'
            f'pose = "{p["pose"]}"\n\n'
        )
