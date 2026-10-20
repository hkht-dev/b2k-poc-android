"""Props the interiors share: the Look point and a framed print on a wall.

Not a part itself: `load_parts` skips names that start with an underscore.
The interior modules import it as `interiors._props` (tools/ is on sys.path
while gen_interiors.py runs, and tools/interiors/ needs no __init__.py for
that).
"""

from __future__ import annotations

from scenegen import Builder, xf

# A Label3D's front is its +Z. Turned half round, a sign on a south wall reads
# from inside the room; a sign on a wall that faces the street reads from the
# pavement to its north.
FACE_NORTH = 3.141592653589793

LOOK_EXT = '[ext_resource type="PackedScene" path="res://scenes/places/LookPoint.tscn" id="look"]\n'


def look(b: Builder, name: str, parent: str, line_id: str, pos, size=(1.6, 2.2, 1.4), yaw=0.0) -> None:
    """Where *Look* is offered (scenes/places/LookPoint.tscn) and which
    dialogue line answers; both data on the node."""
    b.nodes.append(
        f'[node name="{name}" parent="{parent}" instance=ExtResource("look")]\n'
        f"transform = {xf(pos, yaw)}\n"
        f'line_id = "{line_id}"\n'
        f"reach = Vector3({size[0]:g}, {size[1]:g}, {size[2]:g})\n\n"
    )


def framed_print(b: Builder, name: str, parent: str, pos, w: float, h: float, on_x_wall: bool) -> float:
    """A framed photograph flat against a wall: a timber frame and a pale
    print. `pos` is the frame's centre on the wall face; `on_x_wall` says the
    wall runs north-south (the picture is thin in X) rather than east-west.
    Returns the X or Z at which a mark drawn on the print sits just proud of
    it, towards the room (the room is on the origin's side of the wall)."""
    x, y, z = pos
    into = -1.0 if (x if on_x_wall else z) > 0 else 1.0
    if on_x_wall:
        b.solid(name, parent, (x + into * 0.04, y, z), (0.08, h + 0.12, w + 0.12), "timber", collide=False)
        b.solid(f"{name}Print", parent, (x + into * 0.085, y, z), (0.03, h, w), "plaster_cream", collide=False)
        return x + into * 0.11
    b.solid(name, parent, (x, y, z + into * 0.04), (w + 0.12, h + 0.12, 0.08), "timber", collide=False)
    b.solid(f"{name}Print", parent, (x, y, z + into * 0.085), (w, h, 0.03), "plaster_cream", collide=False)
    return z + into * 0.11
