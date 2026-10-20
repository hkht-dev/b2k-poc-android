## The community garden's fruit tree, and the *Pick up* that takes a fruit.
##
## GDD §7 "The Fence" (c): the player may pick fruit for Vasanti before a word
## is said. Picking hands the player a `fruit` (a carryable on the player
## scene), hides one from the branches and fires `fruit_picked`; what that
## means is the quest's to decide from the flags, never this node's. One at a
## time: the button goes while the player is carrying anything.
extends Node3D

signal picked(player: Node3D)

## The item id the player carries (`carryables` on the player scene).
@export var item := "fruit"
## The event fired when a fruit is picked; empty for none. Events fire once.
@export var event := "fruit_picked"

var _taken := 0

@onready var _pick_up: Interactable = $PickUp


func _ready() -> void:
	_pick_up.used.connect(_on_pick_up)


func _physics_process(_delta: float) -> void:
	var player := _find_player()
	_pick_up.enabled = player != null and not player.is_carrying() and fruit_left() > 0


func fruit_left() -> int:
	return _fruit().size() - _taken


func _on_pick_up(player: Node3D) -> void:
	if fruit_left() <= 0 or not player.carry(item):
		return
	_fruit()[_taken].visible = false
	_taken += 1
	if not event.is_empty():
		GameState.fire_event(event)
	picked.emit(player)


func _fruit() -> Array[Node]:
	return get_children().filter(func(node: Node) -> bool: return node.name.begins_with("Fruit"))


func _find_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if not players.is_empty() else null
