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
## and the keys or the left stick move, and the contextual button wears the
## key that presses it. ControlsHint detects the scheme.
##
## Layout (GDD §11 "HUD", owner request 2026-10-20 "intuitive, very easy on
## all devices"): the pause button top-left, the compass top-centre, the
## contextual button bottom-right and the subtitle above it are placed from
## the edges of the display's safe area with a gutter, so a notch or a
## rounded corner never covers them, in portrait and in landscape alike.
extends Control

signal camera_dragged(delta: Vector2)
signal tapped(position: Vector2)
signal pause_pressed
signal scheme_changed(scheme: String)

const TAP_SLOP := 10.0
const TAP_MS := 200
## Gamepad right stick: radians of orbit per second at full deflection, in
## pixel units the camera rig expects.
const STICK_ORBIT_PIXELS_PER_SECOND := 420.0
const SCHEME_TOUCH := "touch"
const CONTROLS_HINT := preload("res://scripts/ui/controls_hint.gd")
## Clearance between the HUD and the edge of the safe area.
const GUTTER := 16.0
## The pause button's size and its place inside the gutter (88 px: a thumb).
const PAUSE_SIZE := 88.0
const PAUSE_AT := Vector2(16.0, 32.0)
const COMPASS_SIZE := Vector2(420.0, 44.0)
const COMPASS_TOP := 24.0
const BUTTON_SIZE := Vector2(180.0, 96.0)
## The contextual button's distance from the gutter's corner, right and up.
const BUTTON_FROM_CORNER := Vector2(32.0, 96.0)
const SUBTITLE_HEIGHT := 60.0
## The subtitle sits this far above the contextual button's top edge.
const SUBTITLE_ABOVE_BUTTON := 62.0
## In portrait the subtitle takes 90 % of the width; in landscape it is a
## readable column, never a line the eye has to travel.
const SUBTITLE_WIDTH_PORTRAIT := 0.9
const SUBTITLE_WIDTH_LANDSCAPE := 880.0
const MINIMAP_SIZE := 300.0
const MINIMAP_FROM_RIGHT := 16.0
const MINIMAP_BELOW_COMPASS := 12.0

## Tests set this to a fake safe area, in this control's coordinates, in
## place of what DisplayServer.get_display_safe_area() reports. Null means
## ask the display.
static var safe_area_override: Variant = null

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
	resized.connect(layout)
	layout()


## Shows the controls for "touch", "desktop" or "gamepad". Only touch has the
## joystick; without it, the whole screen is the camera's and a tap still
## walks there. Off touch, the contextual button wears the key that presses
## it ("E", the gamepad's face button), so a newcomer at a keyboard is told
## without a tutorial; on touch there is no key, so no badge.
func apply_scheme(scheme: String) -> void:
	_scheme = scheme
	_joystick.visible = scheme == SCHEME_TOUCH
	if scheme == SCHEME_TOUCH:
		_button.set_key_badge("")
	else:
		_button.set_key_badge(Strings.t("controls.key.%s_use" % scheme))
	scheme_changed.emit(scheme)


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


func subtitle_label() -> Label:
	return _subtitle


## The part of the screen nothing covers, in this control's coordinates: the
## whole of it but for a phone's notch, rounded corners or system bars. A
## desktop window already sits inside the screen's usable area and a browser
## keeps its own bars out of the page, so only a mobile build asks.
func safe_area() -> Rect2:
	if safe_area_override is Rect2:
		return safe_area_override
	var full := Rect2(Vector2.ZERO, size)
	if not OS.has_feature("mobile"):
		return full
	var screen := Vector2(DisplayServer.screen_get_size())
	if screen.x <= 0.0 or screen.y <= 0.0:
		return full
	var safe := Rect2(DisplayServer.get_display_safe_area())
	# Screen pixels to canvas units: on a phone the canvas is the screen.
	var scale := size / screen
	return Rect2(safe.position * scale, safe.size * scale)


func is_portrait() -> bool:
	return size.x < size.y


## Places every HUD element from the safe area's edges plus the gutter. Runs
## on every resize, so turning the phone or resizing a window re-lays it.
func layout() -> void:
	var safe := safe_area()
	var left := GUTTER + maxf(safe.position.x, 0.0)
	var top := GUTTER + maxf(safe.position.y, 0.0)
	var right := GUTTER + maxf(size.x - safe.end.x, 0.0)
	var bottom := GUTTER + maxf(size.y - safe.end.y, 0.0)

	_pause.position = Vector2(left, top) + PAUSE_AT
	# Square, and never smaller than the theme makes a button.
	var pause_side := maxf(PAUSE_SIZE, _pause.get_combined_minimum_size().y)
	_pause.size = Vector2(pause_side, pause_side)

	_compass.offset_left = -COMPASS_SIZE.x * 0.5
	_compass.offset_right = COMPASS_SIZE.x * 0.5
	_compass.offset_top = top + COMPASS_TOP
	_compass.offset_bottom = _compass.offset_top + COMPASS_SIZE.y

	_button.offset_right = -(right + BUTTON_FROM_CORNER.x)
	_button.offset_left = _button.offset_right - BUTTON_SIZE.x
	_button.offset_bottom = -(bottom + BUTTON_FROM_CORNER.y)
	_button.offset_top = _button.offset_bottom - BUTTON_SIZE.y

	var subtitle_width := (
		size.x * SUBTITLE_WIDTH_PORTRAIT
		if is_portrait()
		else minf(SUBTITLE_WIDTH_LANDSCAPE, size.x - left - right)
	)
	_subtitle.offset_left = -subtitle_width * 0.5
	_subtitle.offset_right = subtitle_width * 0.5
	_subtitle.offset_bottom = _button.offset_top - SUBTITLE_ABOVE_BUTTON
	_subtitle.offset_top = _subtitle.offset_bottom - SUBTITLE_HEIGHT

	_minimap.offset_right = -(right + MINIMAP_FROM_RIGHT)
	_minimap.offset_left = _minimap.offset_right - MINIMAP_SIZE
	_minimap.offset_top = _compass.offset_bottom + MINIMAP_BELOW_COMPASS
	_minimap.offset_bottom = _minimap.offset_top + MINIMAP_SIZE


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
