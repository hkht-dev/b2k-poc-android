"""The chai stall's back door leads to the shrine room (scenes/places/Shrine.tscn).

GDD §5 Hollow Vale: "the shrine room is tucked behind the chai stall, found by
following Tulu or Sarang's music", and it "leaks a faint drone of Madhuri's
chanting under the traffic". GDD §7 "Investigate" step 1: reach the shrine
room behind the chai stall. Tulu's waypoints (gen_street.py) already end at
this door.

The stall's BackDoor mesh stays as gen_street.py draws it; this part only
makes it a door: a Door (verb.enter) into the place "shrine" landing on
"shrine_door", a spawn point outside it for the way back, and the chant,
faint, positional, at the door.
"""

from __future__ import annotations

# The BackDoor mesh is at (13, 1.05, -11.05), on the stall's north face.
DOOR_X = 13.0
DOOR_Z = -11.85
SPAWN_Z = -13.0
FACING_NORTH = 0.0

EXT = (
    '[ext_resource type="AudioStream" path="res://assets/audio/madhuri_chant.ogg" id="shrine_chant"]\n'
)


def build(b) -> None:
    b.door("ShrineDoor", "ChaiStall", "shrine", "shrine_door", "verb.enter",
           (DOOR_X, 0, DOOR_Z), size=(2.0, 2.2, 1.5))
    b.spawn("ShrineSpawn", "ChaiStall", "shrine_door", (DOOR_X, 0, SPAWN_Z), FACING_NORTH)
    # The chant under the traffic (GDD §5): PLACEHOLDER tone, see
    # tools/audio_parts/chant.py. Audible a few metres from the door only.
    b.nodes.append(
        '[node name="ShrineLeak" type="AudioStreamPlayer3D" parent="ChaiStall"]\n'
        f"transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {DOOR_X:g}, 1.4, {DOOR_Z:g})\n"
        'stream = ExtResource("shrine_chant")\n'
        "volume_db = -16.0\nunit_size = 2.0\nmax_distance = 12.0\nautoplay = true\n\n"
    )
