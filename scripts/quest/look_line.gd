## Something that answers the one button with a single line of dialogue:
## *Look* at a door and a thought appears.
##
## GDD §7 "Micro-interactions (no giver, no reward)": a one-line thought,
## opened by what the player does. The verb and the line id are data on the
## node; the line, its speaker and anything it sets live in data/dialogue,
## the way the fountain's *Look* does (scripts/quest/fountain_point.gd),
## minus the fountain. The generators place it in front of the thing.
extends Interactable

## The dialogue line the verb opens; nothing happens if its `requires` fail.
@export var line_id := ""


func _ready() -> void:
	super()
	used.connect(_on_used)


func _on_used(_player: Node3D) -> void:
	if not line_id.is_empty():
		Content.dialogue.start(line_id)
