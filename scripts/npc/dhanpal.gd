## Dhanpal, master of the billboard tower, in front of his hall.
##
## GDD §4 "Dhanpal" (broad, loud, decent underneath), §7 "The Forgotten
## Song" (giver: Dhanpal, at the hall, on arrival) and §8 Scene C. *Talk*
## opens the first of `entry_lines` whose requirements the flags meet, as the
## shopkeepers do (scripts/npc/shopkeeper.gd): the lines, the cards and every
## flag they set live in data/dialogue/en.json, and the order of lines is
## data on the scene. What is his own: he turns to whoever comes near his
## hall and addresses them, then turns back to the street when they go. He
## never follows anyone and never judges the dawn choice: the line after
## *Play it* and the line after *Keep it* are just lines, chosen by flags.
extends Node3D

signal talked(line_id: String)

const TURN_SPEED := 4.0
## He turns to a player this close, in metres: the hall's step and the
## pavement in front of it.
const NOTICE_DISTANCE := 5.0

## Dialogue line ids to try in order; the first whose `requires` hold opens.
@export var entry_lines: PackedStringArray = PackedStringArray()

var _home_yaw := 0.0

@onready var _talk: Interactable = %Talk


func _ready() -> void:
	_home_yaw = rotation.y
	_talk.used.connect(_on_talk)


func _physics_process(delta: float) -> void:
	var player := _find_player()
	if player != null and global_position.distance_to(player.global_position) <= NOTICE_DISTANCE:
		_face(player.global_position, delta)
	else:
		rotation.y = lerp_angle(rotation.y, _home_yaw, TURN_SPEED * delta)


## True while he is turned to someone rather than to the street.
func is_facing_player() -> bool:
	var player := _find_player()
	return player != null and global_position.distance_to(player.global_position) <= NOTICE_DISTANCE


func _on_talk(_player: Node3D) -> void:
	for line_id in entry_lines:
		if Content.dialogue.start(line_id):
			talked.emit(line_id)
			return


func _face(point: Vector3, delta: float) -> void:
	var to := point - global_position
	if to.length() < 0.05:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), TURN_SPEED * delta)


func _find_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if not players.is_empty() else null
