## A sign in the world whose words come from the string table.
##
## CLAUDE_CODE_BRIEF.md §5: no text baked into scenes. The generators place a
## Label3D with this script and a string id; the text is resolved at run
## time, so a locale file changes the shop signs too.
extends Label3D

@export var text_id := ""


func _ready() -> void:
	if not text_id.is_empty():
		text = Strings.t(text_id)
