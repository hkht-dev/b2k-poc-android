"""Two shop fronts on the south flats the player can walk into: the clothes
showroom and the general store (owner expansion 2026-10-20; the insides are
tools/gen_interiors.py). Each is a ground-floor band on the flat's north
face with a doorway, two display windows, an awning, a sign and a Door node
whose spawn id matches the room's own door."""

import math

FACE_Z = 27.0  # the south flats' north face (gen_street.py: Flat9 at (2, 32), Flat10 at (16, 32))
SHOPS = [
    ("Showroom", 2.0, "showroom", "showroom_door", "sign.showroom", "plaster_white"),
    ("Store", 16.0, "store", "store_door", "sign.store", "plaster_cream"),
]


def build(b) -> None:
    b.group("Shopfronts")
    for name, x, place_id, spawn_id, sign_id, band_mat in SHOPS:
        parent = "Shopfronts"
        b.solid(f"{name}Band", parent, (x, 1.75, FACE_Z + 0.2), (10.4, 3.5, 0.6), band_mat)
        b.solid(f"{name}Doorway", parent, (x, 1.2, FACE_Z - 0.18), (1.5, 2.4, 0.16), "tyre", collide=False)
        b.solid(f"{name}FrameL", parent, (x - 0.85, 1.25, FACE_Z - 0.2), (0.14, 2.5, 0.2), "timber", collide=False)
        b.solid(f"{name}FrameR", parent, (x + 0.85, 1.25, FACE_Z - 0.2), (0.14, 2.5, 0.2), "timber", collide=False)
        b.solid(f"{name}Lintel", parent, (x, 2.52, FACE_Z - 0.2), (1.9, 0.14, 0.2), "timber", collide=False)
        for side, dx in (("W", -3.2), ("E", 3.2)):
            b.solid(f"{name}Window{side}", parent, (x + dx, 1.6, FACE_Z - 0.16), (3.2, 2.0, 0.12), "tyre", collide=False)
            b.solid(f"{name}Sill{side}", parent, (x + dx, 0.55, FACE_Z - 0.3), (3.5, 0.1, 0.4), "concrete_dust", collide=False)
        b.solid(f"{name}Awning", parent, (x, 3.05, FACE_Z - 1.0), (6.4, 0.08, 1.8), "canopy", collide=False)
        b.label(f"{name}Sign", parent, sign_id, (x, 3.95, FACE_Z - 0.35), math.pi, size=64)
        b.door(f"{name}Door", parent, place_id, spawn_id, "verb.enter", (x, 0, FACE_Z - 1.1), size=(2.6, 2.2, 1.8))
        b.spawn(f"{name}Spawn", parent, spawn_id, (x, 0, FACE_Z - 1.8), 0.0)
