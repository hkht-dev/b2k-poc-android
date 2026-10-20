## A doorway between places: a shop front on the street, the door inside.
##
## The one contextual button says the door's verb (*Go in*, *Go out*) when
## the player stands at it; using it tells the Place where to go and which
## spawn point to land on. All of that is data on the node, set by the
## generators, never a literal in code.
class_name Door
extends Node3D

signal used_door(place_id: String, spawn_id: String)

const GROUP := "door"

## The place this door leads to (data/places.json).
@export var place_id := ""
## The SpawnPoint in that place the player arrives on.
@export var spawn_id := ""
@export var verb_id := "verb.enter"
## The box in front of the door, in metres, in which the verb is offered.
@export var reach := Vector3(2.4, 2.2, 1.6)

@onready var _use: Interactable = %Use
@onready var _shape: CollisionShape3D = %Shape


func _ready() -> void:
	add_to_group(GROUP)
	_use.verb_id = verb_id
	var box := BoxShape3D.new()
	box.size = reach
	_shape.shape = box
	_shape.position = Vector3(0.0, reach.y * 0.5, 0.0)
	_use.used.connect(_on_used)


func use_area() -> Interactable:
	return _use


func _on_used(_player: Node3D) -> void:
	used_door.emit(place_id, spawn_id)
