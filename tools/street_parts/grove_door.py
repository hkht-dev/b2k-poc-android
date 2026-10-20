"""A way into the Grove from the fountain basin, for development.

Act 2 is one way (GDD §3: the Pool takes the player down to Hollow Vale, and
only Act 5 brings them back up, through the Veil's "veil_up"), so the game
needs no door here. The team does, to reach scenes/places/Grove.tscn without
a title-screen switch: a Door (scenes/places/Door.tscn) on the basin floor
that opens only once `gave_dry_fountain` is set, through the Interactable's
`requires`, so a playtester on the street never meets it by accident. It
lands on the Grove's "pool_bank" spawn, the same one the ascent names. Its
mark is a dark disc on the floor where the Pool would hold the night sky.

PLACEHOLDER: the disc is the Pool's dark material; the real way up is the
Act 5 ascent, not a door.
"""

from scenegen import xf

EXT = '[ext_resource type="Material" path="res://assets/materials/pool.tres" id="mat_pool"]\n'

# On the basin floor (y −0.5), west of where the player surfaces, clear of
# the column and of the spot the P4 tests stand on.
POSITION = (-2.6, -0.5, 2.6)


def build(b) -> None:
    b.nodes.append(
        '[node name="GroveDoor" parent="Fountain" instance=ExtResource("door")]\n'
        "unique_name_in_owner = true\n"
        f"transform = {xf(POSITION)}\n"
        'place_id = "grove"\nspawn_id = "pool_bank"\nverb_id = "verb.descend"\n'
        "reach = Vector3(2.4, 2.2, 2.4)\n"
        'requires = PackedStringArray("gave_dry_fountain")\n\n'
        '[node name="GroveDoorMark" type="MeshInstance3D" parent="Fountain"]\n'
        f"transform = {xf((POSITION[0], POSITION[1] + 0.01, POSITION[2]), 0.0, (3.0, 0.02, 3.0))}\n"
        'mesh = SubResource("CylinderMesh_unit")\n'
        'surface_material_override/0 = ExtResource("mat_pool")\n'
        "cast_shadow = 0\n\n"
    )
