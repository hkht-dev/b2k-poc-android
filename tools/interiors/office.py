"""Dhanpal's office: scenes/places/Office.tscn, the place "office".

GDD §5, Hollow Vale: "four enterable interiors ... Dhanpal's office", and
"Locks, grilles, CCTV cameras and phones appear in every household and shop".
GDD §4: Dhanpal built the tower to be seen from the next valley, so the
photographs on his wall are all of the tower.

A 9 x 7 m room behind the hall front: a big desk with a phone on it, a
leather chair, filing cabinets, a wall of framed photographs of the tower, a
window onto the street, a brass plaque, a camera in a corner and a lock on
the inner door. The photographs, the camera and the lock take *Look* and
answer with a one-line thought each (data/dialogue/en.json, speaker
"thought"); the lock's line sets `noticed_office_lock`. Nothing here is a
score or a marker: the thoughts are the whole reward (GDD §7
"Micro-interactions").

The door and spawn point on the street are tools/street_parts/office_door.py.
The hall itself is another part's.
"""

from __future__ import annotations

import math

from gen_interiors import HEIGHT, assemble, lights, room
from interiors._props import FACE_NORTH, LOOK_EXT, framed_print, look
from scenegen import Builder

W, D = 9.0, 7.0
F = "Fittings"
# Three photographs of the tower on the east wall, north to south, and the
# thought each one answers *Look* with.
PHOTOS = [(-1.7, "office_photo_1"), (0.0, "office_photo_2"), (1.7, "office_photo_3")]


def scene_name() -> str:
    return "Office.tscn"


def scene() -> str:
    b = Builder()
    room(b, W, D, "timber", "plaster_cream", "office_door")
    lights(b, [(-2.2, -1.2), (2.2, -1.2), (0.0, 2.0)], colour=(1.0, 0.9, 0.76))
    b.group(F)
    _desk(b)
    _cabinets(b)
    _photographs(b)
    _plaque(b)
    _camera(b)
    _inner_door(b)
    return assemble(b, "Office", "office", (0.33, 0.29, 0.24), LOOK_EXT)


def _desk(b: Builder) -> None:
    """The big desk mid-room, his chair behind it (south), two for visitors."""
    b.detail("Rug", F, (0.5, 0.012, 1.3), (4.4, 0.02, 3.2), "cloth_pale")
    b.solid("Desk", F, (0.5, 0.37, 1.3), (2.6, 0.74, 1.2), "timber")
    b.detail("DeskTop", F, (0.5, 0.77, 1.3), (2.8, 0.06, 1.4), "timber")
    b.detail("DeskLeather", F, (0.5, 0.805, 1.3), (1.8, 0.01, 0.9), "tyre")
    # Phones everywhere (GDD §5): his, face down by his hand.
    b.detail("Phone", F, (1.5, 0.82, 1.0), (0.08, 0.02, 0.16), "tyre", yaw=0.3)
    b.detail("Ledger", F, (-0.3, 0.83, 1.5), (0.32, 0.05, 0.44), "plaster_white", yaw=-0.15)
    b.detail_cyl("LampBase", F, (-0.6, 0.815, 0.85), 0.09, 0.03, "rust_metal")
    b.detail_cyl("LampStem", F, (-0.6, 1.0, 0.85), 0.012, 0.36, "rust_metal")
    b.detail_cyl("LampShade", F, (-0.6, 1.2, 0.85), 0.12, 0.12, "rust_metal")
    # The leather chair: dark boxes, as the brief says.
    b.solid("ChairSeat", F, (0.5, 0.24, 2.3), (0.62, 0.48, 0.62), "tyre")
    b.detail("ChairBack", F, (0.5, 0.86, 2.6), (0.62, 0.76, 0.12), "tyre")
    for side, dx in (("L", -0.31), ("R", 0.31)):
        b.detail(f"ChairArm{side}", F, (0.5 + dx, 0.58, 2.3), (0.08, 0.2, 0.56), "tyre")
    for i, x in enumerate((-0.3, 1.3)):
        b.solid(f"Visitor{i}", F, (x, 0.22, 0.1), (0.46, 0.44, 0.46), "timber")
        b.detail(f"Visitor{i}Pad", F, (x, 0.47, 0.1), (0.44, 0.06, 0.44), "tyre")
        b.detail(f"Visitor{i}Back", F, (x, 0.72, -0.1), (0.46, 0.5, 0.06), "timber")


def _cabinets(b: Builder) -> None:
    """Three filing cabinets along the west wall, folders on top."""
    handles = []
    for i, z in enumerate((-1.9, -1.1, -0.3)):
        b.solid(f"Cabinet{i}", F, (-4.15, 0.7, z), (0.5, 1.4, 0.7), "rust_metal")
        for y in (0.25, 0.6, 0.95, 1.3):
            handles.append(((-3.89, y, z), 0.0, (0.02, 0.03, 0.14)))
    b.multimesh("CabinetHandles", F, "BoxMesh_unit", "tyre", handles, shadows=False)
    for i, (z, mat) in enumerate(((-1.95, "plaster_cream"), (-1.05, "plaster_white"), (-0.4, "coat"))):
        b.detail(f"Folders{i}", F, (-4.15, 1.46, z), (0.34, 0.12, 0.5), mat, yaw=0.1 * i)


def _photographs(b: Builder) -> None:
    """The wall of the tower: three framed prints on the east wall, each with
    the tower drawn on it in dark print, each with its own *Look*.
    PLACEHOLDER: pictograms in dark boxes stand for the three photographs of
    GDD §7 "Investigate" step 2; the painted prints replace them."""
    for i, (z, line_id) in enumerate(PHOTOS):
        mark_x = framed_print(b, f"Photo{i}", F, (W / 2, 1.7, z), 0.8, 0.6, on_x_wall=True)
        # The tower as a pictogram: a shaft, and what each picture adds.
        b.detail(f"Photo{i}Tower", F, (mark_x, 1.6, z), (0.02, 0.4, 0.07), "tyre")
        if i == 0:  # being built: a crane arm over it
            b.detail(f"Photo{i}Crane", F, (mark_x, 1.86, z + 0.1), (0.02, 0.025, 0.3), "tyre")
        else:  # finished: the billboard on top
            b.detail(f"Photo{i}Board", F, (mark_x, 1.87, z), (0.02, 0.13, 0.32), "tyre")
        if i == 2:  # and him on it
            b.detail(f"Photo{i}Him", F, (mark_x, 1.985, z), (0.02, 0.1, 0.035), "tyre")
        look(b, f"PhotoLook{i}", F, line_id, (W / 2 - 0.75, 0, z), size=(1.4, 2.2, 1.3))


def _plaque(b: Builder) -> None:
    """The brass plaque behind his chair, on the south wall."""
    b.detail("PlaquePlate", F, (0.5, 2.15, D / 2 - 0.03), (1.5, 0.34, 0.04), "rust_metal")
    b.label("Plaque", F, "sign.office", (0.5, 2.15, D / 2 - 0.06), FACE_NORTH, size=30, colour=(0.95, 0.82, 0.5, 1))


def _camera(b: Builder) -> None:
    """A CCTV camera high in the north-east corner, turned on the room."""
    b.detail("CameraArm", F, (W / 2 - 0.16, HEIGHT - 0.3, -D / 2 + 0.4), (0.32, 0.05, 0.05), "rust_metal")
    b.detail("CameraBox", F, (W / 2 - 0.42, HEIGHT - 0.36, -D / 2 + 0.52), (0.16, 0.14, 0.34), "tyre",
            yaw=-math.pi / 4)
    b.detail("CameraLens", F, (W / 2 - 0.55, HEIGHT - 0.36, -D / 2 + 0.65), (0.06, 0.06, 0.02), "plaster_white",
            yaw=-math.pi / 4)
    look(b, "CameraLook", F, "office_camera_look", (W / 2 - 0.8, 0, -D / 2 + 0.6), size=(1.4, 2.2, 1.0))


def _inner_door(b: Builder) -> None:
    """A second door in the south wall, shut, with two locks on it."""
    x, face = -2.6, D / 2
    b.detail("InnerLeaf", F, (x, 1.13, face - 0.05), (1.08, 2.26, 0.08), "timber")
    for side, dx in (("L", -0.6), ("R", 0.6)):
        b.detail(f"InnerFrame{side}", F, (x + dx, 1.15, face - 0.08), (0.12, 2.3, 0.14), "timber")
    b.detail("InnerLintel", F, (x, 2.36, face - 0.08), (1.34, 0.12, 0.14), "timber")
    b.detail("LockBody", F, (x + 0.42, 1.0, face - 0.11), (0.1, 0.18, 0.06), "rust_metal")
    b.detail("LockShackle", F, (x + 0.42, 1.13, face - 0.11), (0.04, 0.1, 0.03), "rust_metal")
    b.detail("Bolt", F, (x + 0.25, 1.5, face - 0.11), (0.34, 0.04, 0.04), "rust_metal")
    look(b, "LockLook", F, "office_lock_look", (x, 0, face - 0.75), size=(1.6, 2.2, 1.4))
