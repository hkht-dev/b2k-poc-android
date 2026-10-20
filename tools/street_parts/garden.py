"""The community garden behind the padlocked fence, and Vasanti at its gate.

GDD §7 "The Fence" (side quest; giver Vasanti, GDD §4). The fence itself —
posts, rails, the gate post and the padlock — is gen_street.py's; it leaves
the gate's span of rail out and this part hangs the gate in it. North of the
fence (z 0..7, x -44..-20): timber beds with dusty soil and a few plants, the
fruit tree (Quaternius Tree_5 with the fruit the thief left on the higher
branches; scripts/quest/fruit_tree.gd), a water drum, the sign, and the gate
that hangs off its hinge so the lock keeps nobody out
(scripts/quest/garden_gate.gd). Vasanti (scenes/npc/Vasanti.tscn) stands at
the gate on the pavement side.

PLACEHOLDER: primitives and CC0 stand-ins (docs/RIGHTS_REGISTER.md) for the
painted garden of GDD §10. Palette: ochre, dust, timber, rust (GDD §10,
Hollow Vale row); the fruit is a warm orange, never peacock blue or magenta.
"""

from __future__ import annotations

from scenegen import xf

EXT = (
    '[ext_resource type="PackedScene" path="res://scenes/npc/Vasanti.tscn" id="vasanti"]\n'
    '[ext_resource type="Script" path="res://scripts/quest/garden_gate.gd" id="garden_gate"]\n'
    '[ext_resource type="Script" path="res://scripts/quest/fruit_tree.gd" id="fruit_tree"]\n'
    '[ext_resource type="Material" path="res://assets/materials/fruit.tres" id="mat_fruit"]\n'
)

FENCE_Z = 7.5
# The fence post west of the gate opening (gen_street.py: posts every 1.9 m
# from x=-44; the span -32.6..-30.7 carries no rail) and the gate post the
# latch meets at x=-30.6, with the padlock hanging on it at x=-31.1.
HINGE_X = -32.6
GATE_WIDTH = 1.84
# The leaf's yaw hanging off its hinge (into the garden, -Z) and swung open.
GATE_YAW_AJAR = 0.45
GATE_YAW_OPEN = 1.35
# Six beds, 2.4 x 1.2 m, in two rows west of the path from the gate. The
# lane at z≈5 stays clear: a pedestrian loop (gen_street.py) walks it.
BED_SIZE = (2.4, 1.2)
BEDS = [(x, z) for x in (-42.3, -39.1, -35.9) for z in (1.4, 3.3)]
TREE = (-25.0, 0.0, 2.4)
TREE_SCALE = 0.7
# Fruit left on the higher branches, relative to the trunk; the low branch is
# bare (that is the quest).
FRUIT = [(-1.5, 2.55, 0.9), (0.9, 2.7, 1.4), (1.6, 2.5, -0.6), (-0.7, 3.0, -1.4), (0.2, 2.45, 1.9)]
FRUIT_SIZE = 0.22
# On the kerb (y 0.16), facing the gate post.
VASANTI = ((-29.3, 0.16, 9.0), 0.7)


def build(b) -> None:
    b.group("Garden")
    _beds(b)
    _tree(b)
    _sign(b)
    _gate(b)
    b.nodes.append(
        '[node name="Vasanti" parent="Garden" instance=ExtResource("vasanti")]\n'
        "unique_name_in_owner = true\n"
        f"transform = {xf(*VASANTI)}\n\n"
    )


def _beds(b) -> None:
    w, d = BED_SIZE
    planks, soil, plants, stakes = [], [], [], []
    for i, (x, z) in enumerate(BEDS):
        for dz in (-d / 2 + 0.04, d / 2 - 0.04):
            planks.append(((x, 0.15, z + dz), 0.0, (w, 0.3, 0.08)))
        for dx in (-w / 2 + 0.04, w / 2 - 0.04):
            planks.append(((x + dx, 0.15, z), 0.0, (0.08, 0.3, d - 0.16)))
        soil.append(((x, 0.11, z), 0.0, (w - 0.16, 0.22, d - 0.16)))
        for dx in (-0.65, 0.65):
            plants.append(((x + dx, 0.2, z), (x * 1.7 + dx) % 6.28, (0.9, 0.8, 0.9)))
        if i % 2:
            for dx in (-0.3, 0.3):
                stakes.append(((x + dx, 0.85, z - 0.25), 0.0, (0.04, 1.3, 0.04)))
    b.multimesh("BedPlanks", "Garden", "BoxMesh_unit", "timber", planks)
    b.multimesh("BedSoil", "Garden", "BoxMesh_unit", "concrete_dust", soil, shadows=False)
    b.multimesh("Stakes", "Garden", "CylinderMesh_unit", "timber", stakes, shadows=False)
    b.batch("Plants", "Garden", "bush", plants, shadows=False)
    b.collider("BedBody", "Garden", (w, 0.3, d), [((x, 0.15, z), 0.0) for x, z in BEDS])
    # The path from the gate up between the beds, and a drum of water.
    b.solid("Path", "Garden", (-31.65, 0.015, 3.6), (1.6, 0.03, 7.0), "concrete_dust", collide=False)
    b.cyl("WaterDrum", "Garden", (-43.0, 0.45, 0.6), 0.32, 0.9, "rust_metal")
    b.collider("DrumBody", "Garden", (0.7, 0.9, 0.7), [((-43.0, 0.45, 0.6), 0.0)])


def _tree(b) -> None:
    x, _, z = TREE
    # The tree as a thing to *Pick up* from (scripts/quest/fruit_tree.gd): the
    # item and the event it fires are data on the node.
    b.nodes.append(
        '[node name="FruitTree" type="Node3D" parent="Garden"]\n'
        "unique_name_in_owner = true\n"
        f"transform = {xf(TREE)}\n"
        'script = ExtResource("fruit_tree")\n'
        'item = "fruit"\nevent = "fruit_picked"\n\n'
        '[node name="PickUp" type="Area3D" parent="Garden/FruitTree"]\n'
        'script = ExtResource("2_interact")\n'
        'verb_id = "verb.pick_up"\n\n'
        '[node name="Shape" type="CollisionShape3D" parent="Garden/FruitTree/PickUp"]\n'
        f"transform = {xf((0, 1.0, 0))}\n"
        f'shape = SubResource("{b.shape_id((4.4, 2.4, 4.4))}")\n\n'
    )
    b.model("Model", "Garden/FruitTree", "tree_5", (0, 0, 0), 0.8, TREE_SCALE)
    for i, pos in enumerate(FRUIT):
        b.nodes.append(
            f'[node name="Fruit{i}" type="MeshInstance3D" parent="Garden/FruitTree"]\n'
            f"transform = {xf(pos, 0.0, (FRUIT_SIZE,) * 3)}\n"
            'mesh = SubResource("SphereMesh_unit")\n'
            'surface_material_override/0 = ExtResource("mat_fruit")\n\n'
        )
    b.collider("TrunkBody", "Garden", (0.6, 4.0, 0.6), [((x, 2.0, z), 0.0)])


def _sign(b) -> None:
    # A white board on two uprights in the span west of the hinge post, read
    # from the pavement (a Label3D faces +Z). Words from the string table.
    x = -35.45
    for i, dx in enumerate((-0.85, 0.85)):
        b.solid(f"SignPost{i}", "Garden", (x + dx, 1.225, FENCE_Z + 0.06), (0.08, 1.25, 0.08), "timber", collide=False)
    b.solid("SignBoard", "Garden", (x, 1.5, FENCE_Z + 0.09), (2.0, 0.62, 0.06), "plaster_white", collide=False)
    ink = (0.18, 0.13, 0.08, 1)
    b.label("GardenSign", "Garden", "sign.garden", (x, 1.62, FENCE_Z + 0.125), size=18, colour=ink)
    b.label("GardenRule", "Garden", "sign.garden_rule", (x, 1.37, FENCE_Z + 0.125), size=12, colour=ink)


def _gate(b) -> None:
    # The gate (scripts/quest/garden_gate.gd) hinged on the fence post west of
    # the opening; the padlock it answers to is the street's own node. Which
    # flag opens it and which event *Mend* fires are data on the node.
    b.nodes.append(
        '[node name="GardenGate" type="Node3D" parent="Garden"]\n'
        "unique_name_in_owner = true\n"
        f"transform = {xf((HINGE_X, 0.0, FENCE_Z))}\n"
        'script = ExtResource("garden_gate")\n'
        'open_flag = "garden_open"\nmend_event = "fence_mended"\n'
        'padlock_path = NodePath("../../Fences/Padlock")\n'
        f"ajar_yaw = {GATE_YAW_AJAR:g}\nopen_yaw = {GATE_YAW_OPEN:g}\n\n"
        '[node name="Leaf" type="Node3D" parent="Garden/GardenGate"]\n'
        f"transform = {xf((0, 0, 0), GATE_YAW_AJAR)}\n\n"
    )
    leaf = "Garden/GardenGate/Leaf"
    mid = GATE_WIDTH / 2
    for name, y in (("RailLow", 0.45), ("RailHigh", 1.05)):
        b.solid(name, leaf, (mid, y, 0), (GATE_WIDTH - 0.16, 0.08, 0.06), "rust_metal", collide=False)
    for i, bx in enumerate((0.16, mid, GATE_WIDTH - 0.12)):
        b.solid(f"Bar{i}", leaf, (bx, 0.62, 0), (0.06, 1.24, 0.06), "rust_metal", collide=False)
    b.solid("Hasp", leaf, (GATE_WIDTH - 0.08, 0.95, 0), (0.08, 0.2, 0.1), "rust_metal", collide=False)
    # *Mend* (scripts/lib/interactable.gd): offered once Vasanti has been
    # talked to (`requires`, data) and, by the script, only with free hands.
    b.nodes.append(
        '[node name="Mend" type="Area3D" parent="Garden/GardenGate"]\n'
        'script = ExtResource("2_interact")\n'
        'verb_id = "verb.fix"\n'
        'requires = PackedStringArray("talked_vasanti")\n\n'
        '[node name="Shape" type="CollisionShape3D" parent="Garden/GardenGate/Mend"]\n'
        f"transform = {xf((mid, 1.0, 0.3))}\n"
        f'shape = SubResource("{b.shape_id((2.4, 2.0, 2.8))}")\n\n'
    )
