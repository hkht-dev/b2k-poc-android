## Something the player set down, lying where they left it.
##
## GDD §6 "Carry": the player picks things up and carries them. Nothing in
## the game took them back except the few places that wanted one — the
## fountain, the shrine lamp, the Grove's stand, Vasanti — so a feather, a
## flower or a kept Veena stayed in the hand for the rest of the journey,
## and every verb that needs an empty hand (a pick-up, the Mend, the Veena
## at dawn) was withdrawn for good. A full hand can now always be emptied
## where the player stands, and what was set down lies there to be picked
## up again: the loop closes.
##
## The look of it is the same scene the hand was holding (`carryables` on
## the player), handed over by the Place, so nothing here knows the items.
extends Node3D

signal picked_up(player: Node3D)

## The item id the player carries (`carryables` on the player scene).
@export var item := ""
## What it looks like: the scene the hand was holding.
@export var model: PackedScene = null

@onready var _pick_up: Interactable = %PickUp


func _ready() -> void:
	_pick_up.used.connect(_on_pick_up)
	if model != null:
		add_child(model.instantiate())


func _physics_process(_delta: float) -> void:
	var player := _find_player()
	_pick_up.enabled = player != null and not player.is_carrying()


func _on_pick_up(player: Node3D) -> void:
	if item.is_empty() or not player.carry(item):
		return
	picked_up.emit(player)
	queue_free()


func _find_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if not players.is_empty() else null
