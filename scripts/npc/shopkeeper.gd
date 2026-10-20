## Someone behind a counter who has a line or two: the storekeeper, the
## tailor. *Talk* opens the first of `entry_lines` whose requirements the
## flags meet; the lines live in data/dialogue, the order is data on the
## scene, as with Gopal (scripts/npc/gopal.gd), minus his walking.
extends Node3D

signal talked(line_id: String)

## Dialogue line ids to try in order; the first whose `requires` hold opens.
@export var entry_lines: PackedStringArray = PackedStringArray()

@onready var _talk: Interactable = %Talk


func _ready() -> void:
	_talk.used.connect(_on_talk)


func _on_talk(_player: Node3D) -> void:
	for line_id in entry_lines:
		if Content.dialogue.start(line_id):
			talked.emit(line_id)
			return
