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
## PLACEHOLDER: a synthesised creak and latch from tools/audio_parts/world.py,
## replaced by the recorded doors of GDD §5's enterable interiors.
const DOOR_OPEN := preload("res://assets/audio/door_open.ogg")

## The place this door leads to (data/places.json).
@export var place_id := ""
## The SpawnPoint in that place the player arrives on.
@export var spawn_id := ""
@export var verb_id := "verb.enter"
## Flags that must all be set before the verb is offered: passed through to
## the Interactable's own `requires` (GDD §12: flags are the only gate).
@export var requires: PackedStringArray = PackedStringArray()
## The box in front of the door, in metres, in which the verb is offered.
@export var reach := Vector3(2.4, 2.2, 1.6)

var _sound: AudioStreamPlayer3D = null

@onready var _use: Interactable = %Use
@onready var _shape: CollisionShape3D = %Shape


func _ready() -> void:
	add_to_group(GROUP)
	_use.verb_id = verb_id
	_use.requires = requires
	var box := BoxShape3D.new()
	box.size = reach
	_shape.shape = box
	_shape.position = Vector3(0.0, reach.y * 0.5, 0.0)
	_sound = AudioStreamPlayer3D.new()
	_sound.stream = DOOR_OPEN
	_sound.position = Vector3(0.0, 1.2, 0.0)
	_sound.unit_size = 4.0
	_sound.max_distance = 20.0
	add_child(_sound)
	_use.used.connect(_on_used)


func use_area() -> Interactable:
	return _use


## The door is sounding: it was just used.
func is_sound_playing() -> bool:
	return _sound.playing


func _on_used(_player: Node3D) -> void:
	_sound.play()
	used_door.emit(place_id, spawn_id)
