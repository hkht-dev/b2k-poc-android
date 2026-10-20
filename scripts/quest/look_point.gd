## Something to *Look* at that has one line to say: a carving on a wall.
##
## GDD §6 "Interaction", §7 micro-interactions ("no giver, no reward"). The
## verb opens `line_id` from the dialogue data; whatever the line sets (that
## it was read, say) is the line's business, not this node's. The fountain
## does the same for itself (scripts/quest/fountain_point.gd); this is the
## plain version for anything with nothing more to do.
extends Node3D

signal looked(line_id: String)

## The dialogue line *Look* opens.
@export var line_id := ""

@onready var _look: Interactable = %Look


func _ready() -> void:
	_look.used.connect(_on_look)


func _on_look(_player: Node3D) -> void:
	if Content.dialogue.start(line_id):
		looked.emit(line_id)
