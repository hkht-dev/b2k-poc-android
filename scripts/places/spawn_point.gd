## Where the player stands on arriving through a named door.
##
## A Door names the spawn point to land on; the Place looks up the one with
## that id among its own and puts the player there, facing the marker's way.
## The ids are data on the nodes (tools/gen_street.py, tools/gen_interiors.py).
class_name SpawnPoint
extends Marker3D

const GROUP := "spawn_point"

@export var spawn_id := ""


func _ready() -> void:
	add_to_group(GROUP)
