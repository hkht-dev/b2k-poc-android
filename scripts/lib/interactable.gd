## Something the player can use with the one contextual button.
##
## GDD §6 "Interaction": the button appears near something usable and is
## labelled with that thing's verb. An interactable is an Area3D the player's
## body overlaps; it carries the verb's string id and, if it is in the
## `sound_source` group, the generic *Listen* (CLAUDE_CODE_BRIEF.md §4.3:
## "any node in group sound_source exposes it. Implement it once.").
class_name Interactable
extends Area3D

## Fired when the player uses the verb. The owner script does the work.
signal used(player: Node3D)

const GROUP := "interactable"
const SOUND_SOURCE_GROUP := "sound_source"

## String id of the verb shown on the button, e.g. "verb.listen".
@export var verb_id := "verb.listen"
## Switched off while the thing cannot be used (mid-climb, mid-walk).
@export var enabled := true


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = 0
	collision_mask = 2
	monitorable = false


func is_available() -> bool:
	return enabled


func use(player: Node3D) -> void:
	if enabled:
		used.emit(player)
