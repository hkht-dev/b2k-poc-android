## Madhuri, who keeps the shrine room behind the chai stall.
##
## GDD §4 "Characters", §8 Scene D: she treats the player as already known
## ("You're the one he's been following") and asks for water for the lamp
## without naming a reward. *Talk* opens the first of `entry_lines` whose
## requirements the flags meet, as with Gopal and the shopkeepers: the order
## is data on the scene, the words and the requirements live in
## data/dialogue. Her chant is the `Chant` child (madhuri_chant.gd); the lamp
## she tends is the room's LampPoint (scripts/quest/lamp_point.gd).
extends Node3D

signal talked(line_id: String)

## Dialogue line ids to try in order; the first whose `requires` hold opens.
@export var entry_lines: PackedStringArray = PackedStringArray()

@onready var _talk: Interactable = %Talk
@onready var _chant: Node3D = %Chant


func _ready() -> void:
	_talk.used.connect(_on_talk)


func chant() -> Node3D:
	return _chant


func _on_talk(_player: Node3D) -> void:
	for line_id in entry_lines:
		if Content.dialogue.start(line_id):
			talked.emit(line_id)
			return
