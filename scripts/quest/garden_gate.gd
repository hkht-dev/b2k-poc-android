## The community garden's gate, and the padlock Vasanti put on it.
##
## GDD §7 "The Fence": the gate hangs off its hinge, so the lock keeps nobody
## out. *Mend* (offered once the player has talked to her, `requires` on the
## node, and only with free hands) lifts it true and fires `fence_mended`,
## which the quest's `fixed` branch reads. When the quest sets `garden_open`
## the padlock — the street's own node, named by `padlock_path` — disappears
## and the gate swings wide. Which flag and which event are data on the node;
## this script only moves the leaf and hides the lock.
extends Node3D

signal mended(player: Node3D)

const SWING_SECONDS := 1.2

## The flag that takes the padlock off (set by the quest data).
@export var open_flag := "garden_open"
## The event *Mend* fires.
@export var mend_event := "fence_mended"
## The street's padlock mesh, hidden while `open_flag` is set.
@export var padlock_path: NodePath
## The leaf's yaw hanging off its hinge, and swung open, in radians. Mended
## is zero: the latch meets the post.
@export var ajar_yaw := 0.45
@export var open_yaw := 1.35

var _tween: Tween = null

@onready var _leaf: Node3D = $Leaf
@onready var _mend: Interactable = $Mend


func _ready() -> void:
	_mend.used.connect(_on_mend)
	GameState.flag_changed.connect(_on_flag_changed)
	_settle(0.0)


func _physics_process(_delta: float) -> void:
	var player := _find_player()
	_mend.enabled = player != null and not player.is_carrying() and not is_settled()


## Mended or open: nothing more is asked of the gate.
func is_settled() -> bool:
	return GameState.has_event(mend_event) or GameState.has_flag(open_flag)


func is_padlocked() -> bool:
	var padlock := _padlock()
	return padlock != null and padlock.visible


func leaf_yaw() -> float:
	return _leaf.rotation.y


func _on_mend(player: Node3D) -> void:
	if is_settled():
		return
	GameState.fire_event(mend_event)
	_settle(SWING_SECONDS)
	mended.emit(player)


func _on_flag_changed(flag: String, is_set: bool) -> void:
	if flag == open_flag and is_set:
		_settle(SWING_SECONDS)


## Puts the gate and the padlock where the journey says, at once or over
## [param seconds].
func _settle(seconds: float) -> void:
	var padlock := _padlock()
	if padlock != null:
		padlock.visible = not GameState.has_flag(open_flag)
	var yaw := ajar_yaw
	if GameState.has_flag(open_flag):
		yaw = open_yaw
	elif GameState.has_event(mend_event):
		yaw = 0.0
	_swing(yaw, seconds)


func _swing(yaw: float, seconds: float) -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	if seconds <= 0.0:
		_leaf.rotation.y = yaw
		return
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_leaf, "rotation:y", yaw, seconds)


func _padlock() -> Node3D:
	if padlock_path.is_empty():
		return null
	return get_node_or_null(padlock_path) as Node3D


func _find_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if not players.is_empty() else null
