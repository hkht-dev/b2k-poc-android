## Hollow Vale, the Street. Wires the touch controls to the player and camera.
##
## GDD §3 Act 3 "Arrival" and CLAUDE_CODE_BRIEF.md §4.1. The player surfaces in
## the dry fountain's basin and climbs out into the block.
##
## This script owns no gameplay rules: it is the seam between input and the
## two things that consume it, so the player and the camera stay testable on
## their own.
##
## All pointing input arrives as screen touches. On desktop the mouse is
## emulated into touches (project.godot), so a right-half mouse drag orbits
## exactly as a thumb would. There is deliberately no second, mouse-motion
## path: Android emulates mouse events *from* touches too, and a second path
## made every thumb on the joystick swing the camera.
extends Node3D

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


func _on_camera_dragged(delta: Vector2) -> void:
	_camera_rig.orbit(delta)
