## A spot in the world that sets a flag when the player stands in it.
##
## GDD §16a "Rooftop running": the end of a run is a place reached, nothing
## counted. Which flag it sets is data on the node (`flag_set`, placed by the
## generators); the flag persists with the journey, so it fires once and a
## loaded journey does not fire it again. It shows nothing and rewards
## nothing: whatever answers the flag (a Glimpse, a line) is another node's.
class_name ReachPoint
extends Area3D

## Fired the one time the flag is set.
signal reached

const PLAYER_GROUP := "player"
const PLAYER_LAYER := 2

## The flag set on arrival (GDD §12: the flag model is the only state).
@export var flag_set := ""


func _ready() -> void:
	collision_layer = 0
	collision_mask = PLAYER_LAYER
	monitorable = false
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if flag_set.is_empty() or not body.is_in_group(PLAYER_GROUP):
		return
	if GameState.set_flag(flag_set):
		reached.emit()
