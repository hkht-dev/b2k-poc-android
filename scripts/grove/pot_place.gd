## Where the water goes: beside Lalita at the feast.
##
## GDD §3 Act 1 "The gathering" ("carry a pot of water to Lalita"), §3a
## ("Pick up a pot, walk it to Lalita, place it — carrying for someone else
## is the main verb"), §6 "Carry". *Place* is offered only while the player
## carries the named item; using it puts the pot down here, where it stays,
## and fires one event. The quest in data/quests/grove_water.json reads the
## event; this script knows nothing about quests or flags.
extends Node3D

signal placed

## The carryable the player must hold (`carryables` on the player scene).
@export var item := "pot"
## The event fired when it is set down.
@export var event := "pot_placed"

@onready var _place: Interactable = $Place
@onready var _pot: Node3D = $PlacedPot


func _ready() -> void:
	_place.used.connect(_on_place)
	_pot.visible = GameState.has_event(event)


func _physics_process(_delta: float) -> void:
	var player := _find_player()
	_place.enabled = player != null and player.is_carrying(item)


func _on_place(player: Node3D) -> void:
	if not player.is_carrying(item):
		return
	player.put_down()
	_pot.visible = true
	GameState.fire_event(event)
	placed.emit()


func _find_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if not players.is_empty() else null
