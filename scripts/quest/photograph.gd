## An old photograph on the shrine wall: *Look* opens its line.
##
## GDD §7 "Investigate" step 2: "Look at three old photographs (a crowd at
## the fountain at dawn; the tower being built; a lamp kept lit)". The line
## ids are data on the scene (`entry_lines`), tried in order: the first whose
## `requires` hold opens, as with the shopkeepers. So each photograph carries
## a second line, same words, that requires the other two to have been seen
## and also sets `saw_shrine` (data/dialogue): whichever is looked at last
## marks the shrine seen, and nothing is counted in code.
extends Node3D

signal looked(line_id: String)

## Dialogue line ids to try in order; the first whose `requires` hold opens.
@export var entry_lines: PackedStringArray = PackedStringArray()

@onready var _look: Interactable = %Look


func _ready() -> void:
	_look.used.connect(_on_look)


func _on_look(_player: Node3D) -> void:
	for line_id in entry_lines:
		if Content.dialogue.start(line_id):
			looked.emit(line_id)
			return
