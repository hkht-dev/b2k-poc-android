## Something lying on the ground that the player can *Pick up* and carry.
##
## The feather a Glimpse leaves (CLAUDE_CODE_BRIEF.md §4.5): picking it up
## does nothing but put it in the hand. The pick-up is recorded as an event
## so a loaded journey does not lay it down again.
extends Node3D

signal picked_up(player: Node3D)

## The item id the player carries (`carryables` on the player scene).
@export var item := "feather"
## The event fired when it is picked up; empty for none.
@export var event := "feather_picked_up"

@onready var _pick_up: Interactable = %PickUp


func _ready() -> void:
	_pick_up.used.connect(_on_pick_up)
	if not event.is_empty() and GameState.has_event(event):
		visible = false


func _physics_process(_delta: float) -> void:
	var player := _find_player()
	_pick_up.enabled = visible and player != null and not player.is_carrying()


func _on_pick_up(player: Node3D) -> void:
	if not player.carry(item):
		return
	visible = false
	if not event.is_empty():
		GameState.fire_event(event)
	picked_up.emit(player)


func _find_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if not players.is_empty() else null
