## Routes touches to the joystick, the camera, taps and the contextual button.
##
## docs/BRIEF_AMENDMENT_1.md §A1 and §A3: two zones tracked by touch index so
## one finger on each side works at once; a drag on the right orbits; a tap on
## the right (under 200 ms, under 10 px) walks the player there; dragging
## never walks. A touch on the contextual button is consumed by the button and
## reaches neither zone. Desktop and web use the same path with the mouse
## emulated into touches; a right-button mouse drag also orbits (§A5), and the
## gamepad's right stick orbits every frame.
##
## The scheme decides what is on screen (§A5, owner request 2026-10-20): on
## touch the joystick owns the left zone; on desktop (a browser on a PC
## included) and gamepad the joystick is hidden, so a drag anywhere orbits
## and the keys or the left stick move. ControlsHint detects the scheme.
extends Control

signal camera_dragged(delta: Vector2)
signal tapped(position: Vector2)
signal pause_pressed

const TAP_SLOP := 10.0
const TAP_MS := 200
## Gamepad right stick: radians of orbit per second at full deflection, in
## pixel units the camera rig expects.
const STICK_ORBIT_PIXELS_PER_SECOND := 420.0
const SCHEME_TOUCH := "touch"
const CONTROLS_HINT := preload("res://scripts/ui/controls_hint.gd")

var _scheme := SCHEME_TOUCH

var _camera_touch := -1
var _camera_start := Vector2.ZERO
var _camera_start_ms := 0
var _camera_last := Vector2.ZERO
var _camera_moved := false
var _mouse_orbiting := false
var _subtitle_left := 0.0

@onready var _joystick: Control = %Joystick
@onready var _button: Button = %ContextualButton
@onready var _pause: Button = %PauseButton
@onready var _minimap: Control = %Minimap
@onready var _subtitle: Label = %Subtitle
@onready var _compass: Control = %Compass


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.pressed.connect(func() -> void: pause_pressed.emit())
	apply_scheme(CONTROLS_HINT.detect_scheme())
	Input.joy_connection_changed.connect(
		func(_device: int, _connected: bool) -> void: apply_scheme(CONTROLS_HINT.detect_scheme())
	)


## Shows the controls for "touch", "desktop" or "gamepad". Only touch has the
## joystick; without it, the whole screen is the camera's and a tap still
## walks there.
func apply_scheme(scheme: String) -> void:
	_scheme = scheme
	_joystick.visible = scheme == SCHEME_TOUCH


func scheme() -> String:
	return _scheme


func minimap() -> Control:
	return _minimap


func compass() -> Control:
	return _compass


## Shows a subtitle by string id for a few seconds (GDD §11 accessibility).
func subtitle(text_id: String, seconds: float = 2.5) -> void:
	_subtitle.text = Strings.t(text_id)
	_subtitle_left = seconds


func subtitle_text() -> String:
	return _subtitle.text


## A box behind the subtitle (brief §7) for readers who need the contrast.
func set_subtitle_box(on: bool) -> void:
	if on:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.1, 0.08, 0.06, 0.7)
		box.set_content_margin_all(10.0)
		box.set_corner_radius_all(8)
		_subtitle.add_theme_stylebox_override("normal", box)
	else:
		_subtitle.remove_theme_stylebox_override("normal")


func has_subtitle_box() -> bool:
	return _subtitle.has_theme_stylebox_override("normal")


func pause_button() -> Button:
	return _pause


func _process(delta: float) -> void:
	if _subtitle_left > 0.0:
		_subtitle_left -= delta
		if _subtitle_left <= 0.0:
			_subtitle.text = ""
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
