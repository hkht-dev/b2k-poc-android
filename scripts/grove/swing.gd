## The swing on the kadamba tree: push it and Lalita laughs.
##
## GDD §7 micro-interactions: "Push the swing on the kadamba tree: Lalita
## laughs." No giver, no reward. *Push* sets one flag (`flag`, data on the
## node), rocks the seat on its ropes for a few seconds, and shows the laugh
## as a subtitle (GDD §11: subtitles for every vocal sound) through the HUD
## of the Place this swing hangs in. The ropes and seat are children of
## `Pivot`, placed by tools/gen_grove.py at the branch, so the whole swing
## turns about the branch.
extends Node3D

signal pushed

const SWINGS := 4
const SWING_SECONDS := 4.4

## The flag a push sets.
@export var flag := "swing_pushed"
## The subtitle shown when she laughs.
@export var subtitle_id := "sub.lalita_laughs"
## How far the first swing goes, in radians.
@export_range(0.05, 1.2, 0.01) var swing_angle := 0.45

var _tween: Tween = null

@onready var _push: Interactable = $Push
@onready var _pivot: Node3D = $Pivot


func _ready() -> void:
	_push.used.connect(_on_push)


func is_swinging() -> bool:
	return _tween != null and _tween.is_running()


func _on_push(_player: Node3D) -> void:
	GameState.set_flag(flag)
	_animate()
	_subtitle(subtitle_id)
	pushed.emit()


## Four swings, each a little shorter, then still.
func _animate() -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	var half := SWING_SECONDS / (SWINGS * 2.0)
	for i: int in SWINGS:
		var amount := swing_angle * (1.0 - float(i) / SWINGS)
		_tween.tween_property(_pivot, "rotation:x", amount, half).set_trans(Tween.TRANS_SINE)
		_tween.tween_property(_pivot, "rotation:x", -amount * 0.7, half).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_pivot, "rotation:x", 0.0, half).set_trans(Tween.TRANS_SINE)


## The HUD belongs to the Place this swing is in.
func _subtitle(text_id: String) -> void:
	var node: Node = get_parent()
	while node != null and not node is Place:
		node = node.get_parent()
	if node == null:
		return
	var controls: Node = node.get_node_or_null("%TouchControls")
	if controls != null and controls.has_method("subtitle"):
		controls.subtitle(text_id)
