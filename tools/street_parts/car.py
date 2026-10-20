"""The car the player can drive, parked at the kerb, and the walls that keep
it on the block.

Owner request 2026-10-20 ("enter inside cars, drive"); GDD §6 (movement).
scenes/vehicles/Car.tscn carries the script, the model and the *Drive* verb;
this only parks it where gen_street.py's PARKED list used to stand the same
SportsCar2 (removed there, so the two never overlap). The block-edge walls
are colliders with no mesh just outside the four ground slabs (x +-65,
z +-45): a car at 11 m/s can never leave the block, and nor can a walker
fall off its edge.
"""

from __future__ import annotations

import math

from scenegen import xf

EXT = '[ext_resource type="PackedScene" path="res://scenes/vehicles/Car.tscn" id="car"]\n'

# At the north kerb of the east-west road, nose east, so the left door opens
# onto the pavement. The body faces -Z; scenegen's xf turns the other way
# from Godot's rotation.y, so +pi/2 here is rotation.y = -pi/2: nose to +X.
CAR_POS = (-12, 0, 11.6)
CAR_YAW = math.pi / 2
# The ground slabs span x +-65 and z +-45; the walls stand just outside, 6 m
# tall, each a little longer than its side so the corners close.
HALF_X, HALF_Z = 65.0, 45.0
WALL_HEIGHT = 6.0
WALL_THICKNESS = 1.0


def build(b) -> None:
    b.group("Vehicles")
    b.nodes.append(
        '[node name="Car" parent="Vehicles" instance=ExtResource("car")]\n'
        "unique_name_in_owner = true\n"
        f"transform = {xf(CAR_POS, CAR_YAW)}\n\n"
    )
    y = WALL_HEIGHT / 2
    far_x = HALF_X + WALL_THICKNESS / 2
    far_z = HALF_Z + WALL_THICKNESS / 2
    b.collider(
        "BlockEdgeNorthSouth", "Vehicles",
        (2 * HALF_X + 2 * WALL_THICKNESS, WALL_HEIGHT, WALL_THICKNESS),
        [((0, y, -far_z), 0.0), ((0, y, far_z), 0.0)],
    )
    b.collider(
        "BlockEdgeEastWest", "Vehicles",
        (WALL_THICKNESS, WALL_HEIGHT, 2 * HALF_Z + 2 * WALL_THICKNESS),
        [((-far_x, y, 0), 0.0), ((far_x, y, 0), 0.0)],
    )
