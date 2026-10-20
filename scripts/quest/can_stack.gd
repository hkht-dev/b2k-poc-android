## Gopal Seth's water cans, and the *Pick up* that takes one.
##
## CLAUDE_CODE_BRIEF.md §4.4: the player picks up a can from the shop stack
## and walks off with it. What that means — a hurt line and a darker street,
## or the first watering — is decided by the quest data from the flags, never
## here: this node only fires `can_taken_from_shop`, hands the player a can
## and hides one from the stack. One at a time: the button goes while the
## player is carrying.
extends Node3D

signal taken(player: Node3D)

const EVENT_TAKEN := "can_taken_from_shop"

var _taken := 0

@onready var _pick_up: Interactable = %PickUp


func _ready() -> void:
	_pick_up.used.connect(_on_pick_up)


func _physics_process(_delta: float) -> void:
	var player := _find_player()
	_pick_up.enabled = (player != null and not player.is_carrying() and _taken < _cans().size())


func cans_left() -> int:
	return _cans().size() - _taken


func _on_pick_up(player: Node3D) -> void:
	if player.is_carrying() or _taken >= _cans().size():
		return
	_cans()[_taken].visible = false
	_taken += 1
	player.carry()
	GameState.fire_event(EVENT_TAKEN)
	taken.emit(player)


func _cans() -> Array[Node]:
	return get_children().filter(func(node: Node) -> bool: return node.name.begins_with("Can"))


func _find_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if not players.is_empty() else null
