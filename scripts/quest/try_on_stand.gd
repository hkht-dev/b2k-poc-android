## The fitting dais in the showroom: stand on it and the one contextual
## button says *Try on*; using it opens the wardrobe over the view.
##
## Owner request 2026-10-20: "go to showroom and try on different clothes".
## GDD §6 "Interaction": one button, labelled with the thing's verb; the verb
## id is data on the Interactable (scenes/quest/TryOnStand.tscn), placed by
## tools/gen_interiors.py. While the wardrobe is open the body stays on the
## dais, the camera comes round to its front (CameraRig.drift_toward) so the
## clothes are seen live, and the verb is withdrawn so a second press cannot
## open a second wardrobe. The screen itself only touches GameState; the
## player's body listens to it (scripts/player/player.gd).
extends Node3D

signal opened(screen: Control)
signal closed

const WARDROBE := preload("res://scenes/ui/WardrobeScreen.tscn")
## How long the camera takes to come round to the front.
const DRIFT_SECONDS := 2.0
## The drift aims the camera away from a point; this far behind the body
## puts the camera in front of it.
const BEHIND := 2.0
## Above the place's HUD (its CanvasLayer is 1), so the panel covers the
## contextual button whose verb it has just taken.
const OVERLAY_LAYER := 2

var _layer: CanvasLayer = null
var _screen: Control = null
var _player: Node3D = null

@onready var _use: Interactable = %Use


func _ready() -> void:
	_use.used.connect(open)


func use_area() -> Interactable:
	return _use


func is_open() -> bool:
	return _screen != null


func screen() -> Control:
	return _screen


## Opens the wardrobe for [param player]. One at a time.
func open(player: Node3D) -> void:
	if _screen != null:
		return
	_player = player
	_use.enabled = false
	if player.has_method("hold_still"):
		player.hold_still(true)
	_layer = CanvasLayer.new()
	_layer.layer = OVERLAY_LAYER
	add_child(_layer)
	_screen = WARDROBE.instantiate()
	_screen.closed.connect(close)
	_layer.add_child(_screen)
	var rig: Node3D = _camera_rig()
	if rig != null and rig.has_method("drift_toward"):
		var behind: Vector3 = player.global_position + player.global_transform.basis.z * BEHIND
		rig.drift_toward(behind, DRIFT_SECONDS)
	opened.emit(_screen)


## *Done*, or a cancel: the wardrobe goes, the body may move again.
func close() -> void:
	if _screen == null:
		return
	_layer.queue_free()
	_layer = null
	_screen = null
	if is_instance_valid(_player) and _player.has_method("hold_still"):
		_player.hold_still(false)
	_player = null
	_use.enabled = true
	closed.emit()


## The place's camera rig, found through the scene that placed this stand;
## a stand instanced on its own has none and the camera stays put.
func _camera_rig() -> Node3D:
	if owner == null:
		return null
	return owner.get_node_or_null("%CameraRig") as Node3D
