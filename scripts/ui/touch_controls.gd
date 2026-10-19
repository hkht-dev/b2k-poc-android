## Routes touches to the joystick, the camera, taps and the contextual button.
##
## docs/BRIEF_AMENDMENT_1.md §A1 and §A3: two zones tracked by touch index so
## one finger on each side works at once; a drag on the right orbits; a tap on
## the right (under 200 ms, under 10 px) walks the player there; dragging
## never walks. A touch on the contextual button is consumed by the button and
## reaches neither zone. Desktop and web use the same path with the mouse
## emulated into touches; a right-button mouse drag also orbits (§A5), and the
## gamepad's right stick orbits every frame.
extends Control

signal camera_dragged(delta: Vector2)
signal tapped(position: Vector2)
signal pause_pressed

const TAP_SLOP := 10.0
const TAP_MS := 200
## Gamepad right stick: radians of orbit per second at full deflection, in
## pixel units the camera rig expects.
const STICK_ORBIT_PIXELS_PER_SECOND := 420.0

var _camera_touch := -1
var _camera_start := Vector2.ZERO
var _camera_start_ms := 0
var _camera_last := Vector2.ZERO
var _camera_moved := false
var _mouse_orbiting := false

@onready var _joystick: Control = %Joystick
@onready var _button: Button = %ContextualButton
@onready var _pause: Button = %PauseButton
@onready var _minimap: Control = %Minimap


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.pressed.connect(func() -> void: pause_pressed.emit())


func minimap() -> Control:
	return _minimap


func pause_button() -> Button:
	return _pause


func _process(delta: float) -> void:
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if stick.length() > 0.08:
		camera_dragged.emit(stick * STICK_ORBIT_PIXELS_PER_SECOND * delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		# The left button is already emulated into touches; the right button
		# is the second way to look on desktop (§A5).
		_mouse_orbiting = event.pressed
	elif event is InputEventMouseMotion and _mouse_orbiting:
		camera_dragged.emit(event.relative)


## This frame's movement wish in screen space, already curved.
func move_vector() -> Vector2:
	if _joystick.is_active():
		return _joystick.vector()
	return Input.get_vector("move_left", "move_right", "move_back", "move_forward")


## Raw deflection for the run timer: the stick's, or 1 for a held key.
func move_deflection() -> float:
	if _joystick.is_active():
		return _joystick.deflection()
	return move_vector().length()


func joystick() -> Control:
	return _joystick


func contextual_button() -> Button:
	return _button


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _joystick.try_claim(event.index, event.position):
			return
		if _camera_touch == -1 and not _over_button(event.position):
			_camera_touch = event.index
			_camera_start = event.position
			_camera_start_ms = Time.get_ticks_msec()
			_camera_last = event.position
			_camera_moved = false
		return

	_joystick.release(event.index)
	if event.index == _camera_touch:
		_camera_touch = -1
		var quick := Time.get_ticks_msec() - _camera_start_ms < TAP_MS
		if not _camera_moved and quick:
			tapped.emit(event.position)


func _on_drag(event: InputEventScreenDrag) -> void:
	_joystick.drag_to(event.index, event.position)
	if event.index != _camera_touch:
		return
	if not _camera_moved and event.position.distance_to(_camera_start) < TAP_SLOP:
		return
	_camera_moved = true
	var delta := event.position - _camera_last
	_camera_last = event.position
	camera_dragged.emit(delta)


func _over_button(position: Vector2) -> bool:
	if _pause.get_global_rect().has_point(position):
		return true
	return _button.visible and _button.get_global_rect().has_point(position)
