## Hollow Vale, the Street. Wires the touch controls to the player and camera.
##
## GDD §3 Act 3 "Arrival" and CLAUDE_CODE_BRIEF.md §4.1. The player surfaces in
## the dry fountain's basin and climbs out into the block.
##
## This script owns no gameplay rules: it is the seam between input and the
## two things that consume it, so the player and the camera stay testable on
## their own.
extends Node3D

## Mouse drag is the desktop stand-in for a right-thumb orbit
## (CLAUDE_CODE_BRIEF.md §4.2).
const MOUSE_DRAG_SCALE := 1.0

@onready var _player: CharacterBody3D = %Player
@onready var _camera_rig: Node3D = %CameraRig
@onready var _controls: Control = %TouchControls


func _ready() -> void:
	# The rig's target is set in the scene, not here: a child's _ready runs
	# before its parent's, so assigning it now would leave the camera at the
	# world origin for one frame before it snapped to the player.
	_controls.camera_dragged.connect(_on_camera_dragged)


func _physics_process(_delta: float) -> void:
	if _player.is_climbing():
		_player.set_move_input(Vector2.ZERO)
		return
	_player.set_move_input(_camera_rig.stick_to_world(_controls.move_vector()))


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion == null:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	_camera_rig.orbit(motion.relative * MOUSE_DRAG_SCALE)


func _on_camera_dragged(delta: Vector2) -> void:
	_camera_rig.orbit(delta)
