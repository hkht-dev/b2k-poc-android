## A seat where a tale is told: *Sit*, and a painted scroll opens.
##
## GDD §3a Act 3: "Sit with Madhuri; tap to turn a painted scroll: Puranjana,
## in three sittings"; §9a "Tales told"; §6 "The Garden": the creeper is
## watered by hearing, which here is the flags a finished sitting leaves.
## Which tale is data on the node (`tale_id`); its sittings and panels are
## data/tales.json. Using the seat sits the player where they stand
## (CharacterRig.hold_pose, the clip the bus stop uses), drifts the camera
## toward the seat and opens scenes/ui/ScrollScreen.tscn on the first
## sitting the journey has not heard to its end; after the last, the last
## again, so a tale can be heard twice. Finishing a sitting sets
## `heard_tale_<id>_<n>`; finishing the last also sets `heard_tale_<id>` and
## adds the tale's line to *Your journey*. Closing early sets nothing.
##
## The seat is the verb and the rule; what it looks like (a cushion, a mat
## beside Madhuri) belongs to the place that holds it. The shrine room will
## hold Madhuri's; the street's is for development (docs/DECISIONS.md).
class_name TaleSeat
extends Node3D

signal sat(tale_id: String, sitting: int)
signal sitting_finished(tale_id: String, sitting: int)
signal stood_up

const SCROLL_SCREEN := preload("res://scenes/ui/ScrollScreen.tscn")
const SIT_POSE := "Sitting_Idle"
const DRIFT_SECONDS := 2.0
## The place's HUD layer, where overlays go so they draw over the controls.
const UI_LAYER := "UI"

## Which tale this seat tells (an id in data/tales.json).
@export var tale_id := "puranjana"

var _scroll: Control = null
var _player: Node3D = null
var _sitting := 0

@onready var _sit: Interactable = %Sit


func _ready() -> void:
	_sit.used.connect(_on_sit)


func _physics_process(_delta: float) -> void:
	_sit.enabled = _scroll == null and offered_sitting() > 0


func is_sitting() -> bool:
	return _scroll != null


## The open scroll, or null.
func scroll() -> Control:
	return _scroll


## The sitting being heard now, or 0.
func current_sitting() -> int:
	return _sitting


## The sitting *Sit* would open: the first the journey has not finished, or
## the last once all have been heard.
func offered_sitting() -> int:
	return Tales.next_sitting(tale_id, GameState.flags)


func _on_sit(player: Node3D) -> void:
	if _scroll != null or player == null:
		return
	var sitting := offered_sitting()
	if sitting <= 0:
		return
	_player = player
	_sitting = sitting
	_hold(player)
	var place := _place()
	if place != null:
		var rig: Node = place.get_node_or_null("%CameraRig")
		if rig != null and rig.has_method("drift_toward"):
			rig.drift_toward(global_position, DRIFT_SECONDS)
	_scroll = SCROLL_SCREEN.instantiate()
	_scroll.finished.connect(_on_finished)
	_scroll.closed.connect(_stand_up)
	_ui_root(place).add_child(_scroll)
	_scroll.open(tale_id, sitting)
	sat.emit(tale_id, sitting)


func _on_finished(finished_tale: String, sitting: int) -> void:
	GameState.set_flag(Tales.sitting_flag(finished_tale, sitting))
	if sitting >= Tales.sitting_count(finished_tale):
		GameState.set_flag(Tales.heard_flag(finished_tale))
		var line_id := Tales.journey_line_id_of(finished_tale)
		if not line_id.is_empty():
			GameState.add_journey_line(line_id)
	sitting_finished.emit(finished_tale, sitting)
	_stand_up()


func _stand_up() -> void:
	if _scroll != null:
		var scroll := _scroll
		_scroll = null
		scroll.get_parent().remove_child(scroll)
		scroll.queue_free()
	if _player != null:
		_release(_player)
		_player = null
	_sitting = 0
	stood_up.emit()


## Holds the player on the seat: their physics stops (no walking off, by
## stick or key, while the scroll is up) and the body holds the sitting
## clip. The one place to change if the Place grows a seam for this.
func _hold(player: Node3D) -> void:
	if player.has_method("set_move_input"):
		player.set_move_input(Vector2.ZERO, 0.0)
	player.set_physics_process(false)
	var rig := player.get_node_or_null("%Mesh") as CharacterRig
	if rig != null:
		rig.hold_pose(SIT_POSE)


func _release(player: Node3D) -> void:
	if player.has_method("set_move_input"):
		player.set_move_input(Vector2.ZERO, 0.0)
	player.set_physics_process(true)
	var rig := player.get_node_or_null("%Mesh") as CharacterRig
	if rig != null:
		rig.release_pose()


## The Place this seat stands in, or null outside one.
func _place() -> Place:
	var node := get_parent()
	while node != null and not node is Place:
		node = node.get_parent()
	return node as Place


func _ui_root(place: Place) -> Node:
	if place != null:
		var ui := place.get_node_or_null(UI_LAYER)
		if ui != null:
			return ui
	return self
