"""Rooftop running: the one route over the south flats (GDD §3a, §16a).

An external stair climbs the west face of Flat9 from the alley. Flat9's and
Flat10's cap slabs become walkable decks with a low parapet lip the player
steps over on purpose; the two-metre gap between the two flats is vaulted at
a run (scripts/player/player.gd). From Flat10's north edge a cable runs down
over the road to a platform on the traffic-light pole, where Krishna was
glimpsed (P5): the route's end, which sets `reached_rooftop`. A second cable
runs on down to the bus-stop shelter roof, and an awning on Flat10's street
face is the short way down. Falling anywhere drops the player to the
pavement; nothing is lost.

The sketch had the first cable reach the shelter roof straight from
Flat10: that is a 4.7 m drop over 4.5 m, steeper than a body can stand on
(docs/DECISIONS.md "Rooftop running"), so the pole comes first and the
shelter second.

PLACEHOLDER: primitives in the street's own materials, replaced by the
painted rooftops, cables and awnings of GDD §10 (Hollow Vale row).
"""

from __future__ import annotations

import math

from scenegen import MAT_ID, xf

EXT = '[ext_resource type="Script" path="res://scripts/quest/reach_point.gd" id="reach_point"]\n'

GROUP = "Rooftops"
# The two flats the run crosses: tools/gen_street.py's `south` entries 3 and
# 4, 12 x 7 x 10 boxes under a 0.4 m cap slab 0.25 m wider all round.
FLATS = {"Flat9": (2.0, 32.0), "Flat10": (16.0, 32.0)}
ROOF_Y = 7.4  # the cap slab's top: where the feet stand
SLAB_W, SLAB_D = 12.5, 10.5
# A lip under the player's STEP_HEIGHT (0.36): walked over when meant, not
# slid over; a run meets it as the edge and leaps from it.
LIP_H, LIP_W = 0.3, 0.5

# The stair: 28 treads up Flat9's west face (the wall is at x = -4), a landing
# at the top over the slab's south-west corner.
STAIR_X, STAIR_W = -4.75, 1.5
STAIR_Z0, STAIR_Z1 = 24.7, 35.3
STEPS = 28
RISE = ROOF_Y / STEPS
DEPTH = (STAIR_Z1 - STAIR_Z0) / STEPS
LANDING = ((-4.55, ROOF_Y - 0.2, 36.0), (2.3, 0.4, 1.4))

# The cables (collider 0.3 m wide, its top on the line; the mesh a 5 cm bar
# centred on the line, so the feet stand just under it), and what they join.
CABLE_W, CABLE_T = 0.3, 0.2
CABLE_MESH = (0.05, 0.05)
STEP_X = 18.0  # where the first cable leaves Flat10's north edge
POLE = (25.5, 6.0, 14.0)  # the traffic-light pole's top (tools/gen_street.py)
PLATFORM = (2.0, 0.16, 2.0)
PLATFORM_Y = POLE[1] + PLATFORM[1] / 2
SHELTER = ((9.0, 2.6, 20.8), (5.2, 0.16, 2.6))  # the bus-stop shelter roof
SHELTER_Y = SHELTER[0][1] + SHELTER[1][1] / 2
CABLE_A = ((STEP_X, ROOF_Y + LIP_H, 26.3), (POLE[0], PLATFORM_Y, POLE[2] + PLATFORM[2] / 2))
# Cable B leaves from the end of its step, which reaches B_STEP_OUT past the
# platform's west edge toward the shelter roof's east edge, so step and
# cable meet flush.
B_STEP_OUT = 0.8
_B_FROM = (POLE[0] - PLATFORM[0] / 2, POLE[2])
_B_TO = (11.6, 20.6)
_B_LEN = math.hypot(_B_TO[0] - _B_FROM[0], _B_TO[1] - _B_FROM[1])
_B_DIR = ((_B_TO[0] - _B_FROM[0]) / _B_LEN, (_B_TO[1] - _B_FROM[1]) / _B_LEN)
CABLE_B = (
    (_B_FROM[0] + _B_DIR[0] * B_STEP_OUT, PLATFORM_Y + 0.03, _B_FROM[1] + _B_DIR[1] * B_STEP_OUT),
    (_B_TO[0], SHELTER_Y, _B_TO[1]),
)

REACH_FLAG = "reached_rooftop"


def _num(n: float) -> str:
    n = round(n, 6)
    return f"{n + 0.0:g}"


def _basis(start, end):
    """Unit axes (x, y, z) of a box whose local Z runs start -> end, with Y as
    upright as the slope allows, and the run's length."""
    d = [e - s for s, e in zip(start, end)]
    length = math.sqrt(sum(c * c for c in d))
    z = [c / length for c in d]
    x = [z[2], 0.0, -z[0]]  # UP x z, flat
    xl = math.hypot(x[0], x[2])
    x = [x[0] / xl, 0.0, x[2] / xl]
    y = [z[1] * x[2] - z[2] * x[1], z[2] * x[0] - z[0] * x[2], z[0] * x[1] - z[1] * x[0]]
    return x, y, z, length


def _tf(axes, scale, origin) -> str:
    """A Transform3D in scene-file order: the basis row by row, then the origin."""
    x, y, z = axes
    sx, sy, sz = scale
    v = [
        x[0] * sx, y[0] * sy, z[0] * sz,
        x[1] * sx, y[1] * sy, z[1] * sz,
        x[2] * sx, y[2] * sy, z[2] * sz,
        *origin,
    ]
    return "Transform3D(" + ", ".join(_num(n) for n in v) + ")"


def _beam(b, name, parent, start, end, width, thickness, mat=None, group=None, mesh=None) -> None:
    """A box whose top surface runs start -> end along its centre line: a
    ramp, a rail, a cable. Collider `width` x `thickness`; with `mat` it is
    drawn, as a box the collider's size or, with `mesh` (w, h), as a bar
    centred on the line."""
    x, y, z, length = _basis(start, end)
    centre = [(s + e) / 2 for s, e in zip(start, end)]
    origin = [c - yy * thickness / 2 for c, yy in zip(centre, y)]
    groups = f' groups=["{group}"]' if group else ""
    b.nodes.append(
        f'[node name="{name}" type="StaticBody3D" parent="{parent}"{groups}]\n'
        f"transform = {_tf((x, y, z), (1, 1, 1), origin)}\n"
        "collision_layer = 1\ncollision_mask = 0\n\n"
        f'[node name="Shape" type="CollisionShape3D" parent="{parent}/{name}"]\n'
        f'shape = SubResource("{b.shape_id((width, thickness, length))}")\n\n'
    )
    if mat is None:
        return
    if mesh is None:
        mesh_xf = xf((0, 0, 0), 0.0, (width, thickness, length))
    else:
        mesh_xf = xf((0, thickness / 2, 0), 0.0, (mesh[0], mesh[1], length))
    b.nodes.append(
        f'[node name="Mesh" type="MeshInstance3D" parent="{parent}/{name}"]\n'
        f"transform = {mesh_xf}\n"
        'mesh = SubResource("BoxMesh_unit")\n'
        f'surface_material_override/0 = ExtResource("{MAT_ID[mat]}")\n\n'
    )


def _ramp_y(z: float) -> float:
    """Height of the stair's walking line at z: through each tread's mid-point."""
    return RISE / 2 + RISE * (z - STAIR_Z0) / DEPTH


def _step(b, name, cable, inner, outer, width, top, mat="concrete_dust") -> None:
    """A level block in the `cable` group where a cable begins, `inner` metres
    back from its start and `outer` past it, its local Z along the cable.
    Stepping onto it is already stepping onto the line: the player's balance
    takes the stick along the cable before the cable is under the feet, so
    a push a few degrees off does not miss a 0.3 m start and fall."""
    (sx, _sy, sz), (ex, _ey, ez) = cable
    dx, dz = ex - sx, ez - sz
    length = math.hypot(dx, dz)
    dx, dz = dx / length, dz / length
    start = (sx - dx * inner, top, sz - dz * inner)
    end = (sx + dx * outer, top, sz + dz * outer)
    _beam(b, name, GROUP, start, end, width, LIP_H, mat, group="cable")


def build(b) -> None:
    b.group(GROUP)

    # --- decks and lips ---------------------------------------------------
    # The cap slabs (Flat<i>Parapet) are meshes: a collider at their top puts
    # the feet on what the eye sees.
    b.collider(
        "Decks", GROUP, (SLAB_W, 0.4, SLAB_D),
        [((x, ROOF_Y - 0.2, z), 0.0) for x, z in FLATS.values()],
    )
    f9x, f9z = FLATS["Flat9"]
    f10x, f10z = FLATS["Flat10"]
    north9, south9 = f9z - SLAB_D / 2 + LIP_W / 2, f9z + SLAB_D / 2 - LIP_W / 2
    west9, east9 = f9x - SLAB_W / 2 + LIP_W / 2, f9x + SLAB_W / 2 - LIP_W / 2
    west10, east10 = f10x - SLAB_W / 2 + LIP_W / 2, f10x + SLAB_W / 2 - LIP_W / 2
    landing_z0 = LANDING[0][2] - LANDING[1][2] / 2
    step_x0, step_x1 = STEP_X - 1.4, STEP_X + 1.4
    slab10_x0, slab10_x1 = f10x - SLAB_W / 2, f10x + SLAB_W / 2
    slab_z0 = f9z - SLAB_D / 2
    # (centre x, centre z, length, runs along z)
    lips = [
        (f9x, north9, SLAB_W, False),
        (f9x, south9, SLAB_W, False),
        (east9, f9z, SLAB_D, True),
        (west9, (slab_z0 + landing_z0) / 2, landing_z0 - slab_z0, True),  # stops at the landing
        ((slab10_x0 + step_x0) / 2, north9, step_x0 - slab10_x0, False),  # either side of
        ((step_x1 + slab10_x1) / 2, north9, slab10_x1 - step_x1, False),  # the cable step
        (f10x, south9, SLAB_W, False),
        (west10, f10z, SLAB_D, True),
        (east10, f10z, SLAB_D, True),
    ]
    by_length: dict[float, list] = {}
    for cx, cz, length, along_z in lips:
        by_length.setdefault(round(length, 3), []).append(
            ((cx, ROOF_Y + LIP_H / 2, cz), math.pi / 2 if along_z else 0.0)
        )
    for i, (length, placements) in enumerate(sorted(by_length.items())):
        b.collider(f"Lips{i}", GROUP, (length, LIP_H, LIP_W), placements)
    b.multimesh(
        "LipMesh", GROUP, "BoxMesh_unit", "concrete_dust",
        [((cx, ROOF_Y + LIP_H / 2, cz), math.pi / 2 if along_z else 0.0, (length, LIP_H, LIP_W))
         for cx, cz, length, along_z in lips],
        shadows=False,
    )

    # --- the stair up Flat9, from the alley --------------------------------
    b.multimesh(
        "StairTreads", GROUP, "BoxMesh_unit", "ph_concrete",
        [((STAIR_X, (i + 1) * RISE / 2, STAIR_Z0 + (i + 0.5) * DEPTH), 0.0, (STAIR_W, (i + 1) * RISE, DEPTH))
         for i in range(STEPS)],
    )
    # The feet ride a ramp through the treads' mid-points (within 0.13 m).
    _beam(b, "Stair", GROUP, (STAIR_X, _ramp_y(STAIR_Z0), STAIR_Z0), (STAIR_X, _ramp_y(STAIR_Z1), STAIR_Z1), STAIR_W, 0.3)
    rail_x = STAIR_X - STAIR_W / 2 - 0.06
    _beam(
        b, "StairRail", GROUP,
        (rail_x, _ramp_y(STAIR_Z0) + 1.0, STAIR_Z0), (rail_x, _ramp_y(STAIR_Z1) + 1.0, STAIR_Z1),
        0.06, 0.06, "rust_metal",
    )
    b.multimesh(
        "RailPosts", GROUP, "BoxMesh_unit", "rust_metal",
        [((rail_x, _ramp_y(z) + 0.5, z), 0.0, (0.06, 1.0, 0.06))
         for z in (STAIR_Z0 + k * (STAIR_Z1 - STAIR_Z0) / 5 for k in range(6))],
        shadows=False,
    )
    b.solid("StairLanding", GROUP, LANDING[0], LANDING[1], "ph_concrete")
    # A rail on the landing's blind side: the stair arrives at a run.
    b.solid(
        "LandingRail", GROUP,
        (LANDING[0][0], ROOF_Y + 0.45, LANDING[0][2] + LANDING[1][2] / 2 - 0.03),
        (LANDING[1][0], 0.9, 0.06), "rust_metal",
    )
    # The start, marked: a plate on the flat's street corner beside the stair.
    b.solid("SignBoard", GROUP, (-3.2, 2.5, 26.68), (1.5, 0.45, 0.05), "sign", collide=False)
    b.label("StairsSign", GROUP, "sign.stairs", (-3.2, 2.5, 26.63), math.pi, size=26)

    # --- the cable run: Flat10 -> the pole -> the shelter --------------------
    _step(b, "CableStep", CABLE_A, 2.4, 0.0, 1.6, ROOF_Y + LIP_H)
    _beam(b, "CableA", GROUP, CABLE_A[0], CABLE_A[1], CABLE_W, CABLE_T, "tyre", group="cable", mesh=CABLE_MESH)
    b.solid("PolePlatform", GROUP, POLE, PLATFORM, "rust_metal")
    # Rails on the two sides no cable leaves by: cable A arrives from the
    # south at a run, and the platform is two metres deep.
    b.solid(
        "PlatformRailN", GROUP, (POLE[0], PLATFORM_Y + 0.45, POLE[2] - PLATFORM[2] / 2 + 0.03),
        (PLATFORM[0], 0.9, 0.06), "rust_metal",
    )
    b.solid(
        "PlatformRailE", GROUP, (POLE[0] + PLATFORM[0] / 2 - 0.03, PLATFORM_Y + 0.45, POLE[2]),
        (0.06, 0.9, PLATFORM[2]), "rust_metal",
    )
    # Cable B's step is the platform's whole west half, a hair above it so the
    # feet read it first: heading west from anywhere on the platform is
    # heading onto the cable.
    _step(b, "CableBStep", CABLE_B, PLATFORM[0] / 2 + B_STEP_OUT, 0.0, PLATFORM[2], PLATFORM_Y + 0.03, "rust_metal")
    _beam(b, "CableB", GROUP, CABLE_B[0], CABLE_B[1], CABLE_W, CABLE_T, "tyre", group="cable", mesh=CABLE_MESH)
    b.collider("ShelterRoof", GROUP, SHELTER[1], [(SHELTER[0], 0.0)])
    # The short way down from Flat10: a step off the north lip onto the awning
    # over the ground-floor windows (3.5 m), and from there to the pavement.
    b.solid("Awning", GROUP, (14.0, 3.85, 25.65), (4.4, 0.1, 2.2), "canopy")

    # --- the route's end: where Krishna was glimpsed ------------------------
    b.nodes.append(
        f'[node name="RooftopReach" type="Area3D" parent="{GROUP}"]\n'
        f"transform = {xf((POLE[0], PLATFORM_Y + 1.0, POLE[2]))}\n"
        "collision_layer = 0\ncollision_mask = 2\nmonitorable = false\n"
        'script = ExtResource("reach_point")\n'
        f'flag_set = "{REACH_FLAG}"\n\n'
        f'[node name="Shape" type="CollisionShape3D" parent="{GROUP}/RooftopReach"]\n'
        f'shape = SubResource("{b.shape_id((PLATFORM[0] + 0.2, 2.0, PLATFORM[2] + 0.2))}")\n\n'
    )
