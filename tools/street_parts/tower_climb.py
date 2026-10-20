"""The billboard tower's climb and its roof: the stair, the ladder with four
landings, the carving, the Veena on its stand, and the beam no one reaches.

GDD §3a "Climb the tower at dawn: ladder, four landings"; §5 Hollow Vale ("the
billboard tower on Dhanpal's roof, reachable by stairs and a ladder, 4 landings;
a top beam no one can reach") and Rooftop ("the Veena on its stand, the whole
city below"); §7 micro-interactions ("Read Nanda's brother's name carved on the
tower's second landing"); §8 Scene E "The dawn choice". The tower itself (the
block, the legs, the billboard) is gen_street.py's "Tower" group; everything
here hangs off that group and nothing in gen_street.py changes.

Layout: the block is 15 x 14 x 15 at (-31, 7, -26), so its east face is
x = -23.5 and the alley between it and the next flat runs x -23.5..-15.5. The
roof's visible lid (gen_street's "Parapet" slab) tops out at y 14.45 and had
no collision; a collider here makes it the walkable surface, so the fourth
landing is the roof lid itself. The stair climbs the east face from the alley
to the first landing; the ladder runs in the slot between the wall and the
landing decks; each landing's area is one segment (scripts/street/ladder.gd).

PLACEHOLDER: primitives (a concrete stair, steel landings and ladder, a timber
stand) and the Veena of scenes/quest/Veena.tscn, replaced by the custom tower
and Veena of GDD §5 "Reuse plan" and §10.
"""

from __future__ import annotations

import math

from scenegen import MAT_ID, xf

# ext_resource ids carry a prefix so no other part's ids collide with them.
EXT = (
    '[ext_resource type="Script" path="res://scripts/street/ladder.gd" id="tower_ladder"]\n'
    '[ext_resource type="PackedScene" path="res://scenes/quest/TowerTop.tscn" id="tower_top"]\n'
    '[ext_resource type="PackedScene" path="res://scenes/quest/Carving.tscn" id="tower_carving"]\n'
)

PARENT = "Tower"
WALL_X = -23.5  # the block's east face
ROOF_Y = 14.45  # top of the roof lid, the walkable surface
ROOF_CENTRE = (-31.0, ROOF_Y, -26.0)
LADDER_Z = -27.0
LADDER_X = -23.35  # the poles, in the slot between the wall and the decks
# Landing deck tops: three 3.5 m apart, then the roof lid.
LANDING_Y = [3.5, 7.0, 10.5, ROOF_Y]
DECK_X = -22.45  # deck centre: the deck spans x -23.25..-21.65
DECK_W, DECK_D, DECK_T = 1.6, 1.8, 0.12
RAIL_H = 1.05
# The stair: risers low enough for the player's 0.36 m step (player.gd
# STEP_HEIGHT), fourteen of them to the first landing, hugging the wall.
STEP_RISE, STEP_DEPTH, STEP_COUNT = 0.25, 0.36, 14
STAIR_X = (WALL_X + DECK_X + DECK_W / 2) / 2
STAIR_W = DECK_X + DECK_W / 2 - WALL_X
RUNG_SPACING = 0.3


def pitched(pos, dy, dz, scale=(1, 1, 1)) -> str:
    """A Transform3D whose Z axis runs along (0, dy, dz): a rail, or a
    collider, laid along a slope. The scene text is the basis row by row
    (Godot's VariantParser), so each row holds one component of all three
    scaled axes; the frame stays right-handed."""
    length = math.hypot(dy, dz)
    uy, uz = dy / length, dz / length
    sx, sy, sz = scale
    # axes: x = (1, 0, 0), y = (0, -uz, uy), z = (0, -uy, -uz); x cross y = z.
    v = [sx, 0, 0, 0, -uz * sy, -uy * sz, 0, uy * sy, -uz * sz, *pos]
    return "Transform3D(" + ", ".join(f"{n:g}" for n in v) + ")"


def build(b) -> None:
    # --- the roof lid is walkable ---------------------------------------
    b.collider("RoofDeck", PARENT, (15.6, 0.5, 15.6), [((-31, 14.2, -26), 0.0)])

    # --- the external stair, alley to the first landing -------------------
    deck_south = LADDER_Z + DECK_D / 2
    steps, treads = [], []
    for i in range(STEP_COUNT):
        top = STEP_RISE * (i + 1)
        z = deck_south + STEP_DEPTH / 2 + (STEP_COUNT - 1 - i) * STEP_DEPTH
        # Each step is drawn as a full-height block so the stair is solid
        # underneath; only its tread needs collision.
        steps.append(((STAIR_X, top / 2, z), 0.0, (STAIR_W, top, STEP_DEPTH)))
        treads.append(((STAIR_X, top - STEP_RISE / 2, z), 0.0))
    b.multimesh("StairSteps", PARENT, "BoxMesh_unit", "concrete_dust", steps)
    b.collider("StairBody", PARENT, (STAIR_W, STEP_RISE, STEP_DEPTH), treads)
    # A handrail along the open (east) side, and a collider so the stair's
    # edge is not a drop.
    rail_x = DECK_X + DECK_W / 2 + 0.03
    foot = (rail_x, STEP_RISE + 1.0, steps[0][0][2])
    head = (rail_x, STEP_RISE * STEP_COUNT + 1.0, steps[-1][0][2])
    dy, dz = head[1] - foot[1], head[2] - foot[2]
    mid = tuple((p + q) / 2 for p, q in zip(foot, head))
    length = math.hypot(dy, dz)
    b.nodes.append(
        f'[node name="StairRail" type="MeshInstance3D" parent="{PARENT}"]\n'
        f"transform = {pitched(mid, dy, dz, (0.06, 0.06, length))}\n"
        'mesh = SubResource("BoxMesh_unit")\n'
        f'surface_material_override/0 = ExtResource("{MAT_ID["rust_metal"]}")\n\n'
    )
    rail_mid = (rail_x, mid[1] - 1.0 + RAIL_H / 2, mid[2])
    b.nodes.append(
        f'[node name="StairRailBody" type="StaticBody3D" parent="{PARENT}"]\n'
        "collision_layer = 1\ncollision_mask = 0\n\n"
        f'[node name="Shape" type="CollisionShape3D" parent="{PARENT}/StairRailBody"]\n'
        f"transform = {pitched(rail_mid, dy, dz)}\n"
        f'shape = SubResource("{b.shape_id((0.08, RAIL_H, length))}")\n\n'
    )
    posts = [
        ((rail_x, STEP_RISE * (i + 1) + 0.5, steps[i][0][2]), 0.0, (0.06, 1.0, 0.06))
        for i in (0, 4, 9, 13)
    ]

    # --- four landings: decks, rails, posts ------------------------------
    decks, rails, deck_bodies, rail_east, rail_sides = [], [], [], [], []
    for n, y in enumerate(LANDING_Y):
        decks.append(((DECK_X, y - DECK_T / 2, LADDER_Z), 0.0, (DECK_W, DECK_T, DECK_D)))
        deck_bodies.append(((DECK_X, y - DECK_T / 2, LADDER_Z), 0.0))
        east = DECK_X + DECK_W / 2 - 0.03
        for ry in (0.5, 1.0):
            rails.append(((east, y + ry, LADDER_Z), 0.0, (0.05, 0.05, DECK_D)))
        rail_east.append(((east, y + RAIL_H / 2, LADDER_Z), 0.0))
        # The first landing's south side is where the stair arrives; the
        # others are railed on both sides. West is the wall and the ladder;
        # on the roof lid, west is the roof.
        for side in ((-1,) if n == 0 else (-1, 1)):
            z = LADDER_Z + side * (DECK_D / 2 - 0.03)
            for ry in (0.5, 1.0):
                rails.append(((DECK_X, y + ry, z), 0.0, (DECK_W, 0.05, 0.05)))
            rail_sides.append(((DECK_X, y + RAIL_H / 2, z), 0.0))
        for sx in (-1, 1):
            for sz in (-1, 1):
                posts.append((
                    (DECK_X + sx * (DECK_W / 2 - 0.03), y + RAIL_H / 2, LADDER_Z + sz * (DECK_D / 2 - 0.03)),
                    0.0, (0.06, RAIL_H, 0.06),
                ))
    b.multimesh("LandingDecks", PARENT, "BoxMesh_unit", "rust_metal", decks)
    b.multimesh("LandingRails", PARENT, "BoxMesh_unit", "rust_metal", rails, shadows=False)
    b.multimesh("LandingPosts", PARENT, "BoxMesh_unit", "rust_metal", posts, shadows=False)
    b.collider("LandingDeckBody", PARENT, (DECK_W, DECK_T, DECK_D), deck_bodies)
    b.collider("LandingRailEastBody", PARENT, (0.08, RAIL_H, DECK_D), rail_east)
    b.collider("LandingRailSideBody", PARENT, (DECK_W, RAIL_H, 0.08), rail_sides)

    # --- the ladder: a pole pair and its rungs ----------------------------
    pole_bottom, pole_top = LANDING_Y[0], ROOF_Y + 0.15
    b.multimesh(
        "LadderPoles", PARENT, "CylinderMesh_unit", "rust_metal",
        [((LADDER_X, (pole_bottom + pole_top) / 2, LADDER_Z + s * 0.25), 0.0, (0.08, pole_top - pole_bottom, 0.08))
         for s in (-1, 1)],
    )
    rung_count = int((ROOF_Y - pole_bottom) / RUNG_SPACING)
    b.multimesh(
        "LadderRungs", PARENT, "BoxMesh_unit", "rust_metal",
        [((LADDER_X, pole_bottom + RUNG_SPACING * (k + 1), LADDER_Z), 0.0, (0.05, 0.04, 0.5))
         for k in range(rung_count)],
        shadows=False,
    )

    # --- the segments: a landing node, its exit, and the area that climbs --
    # The area faces the wall, so a body moving west into the rungs is the
    # whole input (GDD §6: no jump button). scenegen.xf writes the basis row
    # by row, which Godot reads as a turn of -yaw: -pi/2 here points the
    # area's forward (-Z) at -X.
    for n, y in enumerate(LANDING_Y):
        b.nodes.append(
            f'[node name="Landing{n}" type="Node3D" parent="{PARENT}"]\n'
            f"transform = {xf((DECK_X, y, LADDER_Z))}\n\n"
            f'[node name="Exit" type="Marker3D" parent="{PARENT}/Landing{n}"]\n'
            f"transform = {xf((0, 0.05, 0))}\n\n"
        )
        if n + 1 < len(LANDING_Y):
            b.nodes.append(
                f'[node name="Ladder" type="Area3D" parent="{PARENT}/Landing{n}"]\n'
                f"transform = {xf((0, 1.0, 0), -math.pi / 2)}\n"
                "collision_layer = 0\ncollision_mask = 2\nmonitorable = false\n"
                'script = ExtResource("tower_ladder")\n'
                f'exit_marker_path = NodePath("../../Landing{n + 1}/Exit")\n\n'
                f'[node name="Shape" type="CollisionShape3D" parent="{PARENT}/Landing{n}/Ladder"]\n'
                f'shape = SubResource("{b.shape_id((DECK_D, 2.0, DECK_W))}")\n\n'
            )

    # --- Nanda's brother's name, on the wall at the second landing (§7) ----
    b.nodes.append(
        f'[node name="Carving" parent="{PARENT}" instance=ExtResource("tower_carving")]\n'
        f"transform = {xf((WALL_X, LANDING_Y[1], LADDER_Z))}\n\n"
    )

    # --- the roof: the Veena on its stand at the centre (§5, §8 Scene E) ---
    b.nodes.append(
        f'[node name="TowerTop" parent="{PARENT}" instance=ExtResource("tower_top")]\n'
        "unique_name_in_owner = true\n"
        f"transform = {xf(ROOF_CENTRE)}\n\n"
    )

    # --- the top beam no one can reach (§5): above the billboard frame ------
    # Nothing climbs to it: no segment's exit is above the roof lid.
    b.solid("TopBeam", PARENT, (-31, 26.0, -26.3), (14.4, 0.3, 0.3), "rust_metal", collide=False)
