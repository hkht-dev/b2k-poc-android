## Left-thumb virtual joystick. Invisible until a thumb lands on it.
##
## GDD §11 "HUD": the joystick fades in on touch and nothing else is on screen.
## Side, size and opacity are adjustable (GDD §11 "Controls"); the settings
## screen that drives them is P6, so for now they are editor properties.
extends Control

signal moved(vector: Vector2)

const FADE_SPEED := 6.0

@export_range(48.0, 220.0, 1.0) var radius := 120.0
@export_range(0.1, 1.0, 0.05) var max_opacity := 0.35
## Which thumb owns this control. Mirrors the whole layout when set to right.
@export_enum("left", "right") var side := "left"

var _touch_index := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO
var _vector := Vector2.ZERO
var _shown := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	var wanted := 1.0 if _touch_index != -1 else 0.0
	_shown = move_toward(_shown, wanted, FADE_SPEED * delta)
	queue_redraw()


func _draw() -> void:
	if _shown <= 0.01:
		return
	var base := Color(0.42, 0.31, 0.208, max_opacity * _shown)
	var knob := Color(0.957, 0.925, 0.847, max_opacity * 2.0 * _shown)
	draw_arc(_origin, radius, 0.0, TAU, 48, base, 3.0, true)
	draw_circle(_knob, radius * 0.32, knob)


## Returns the current stick vector: x right, y forward (already negated so
## that pushing up the screen is forward).
func vector() -> Vector2:
	return _vector


func is_active() -> bool:
	return _touch_index != -1


## Claims a touch that began at [param position]. Returns false when this
## joystick is not responsible for that half of the screen.
func try_claim(index: int, position: Vector2) -> bool:
	if _touch_index != -1 or not owns_point(position):
		return false
	_touch_index = index
	_origin = position
	_knob = position
	_vector = Vector2.ZERO
	return true


func drag_to(index: int, position: Vector2) -> void:
	if index != _touch_index:
		return
	var offset := position - _origin
	if offset.length() > radius:
		offset = offset.normalized() * radius
	_knob = _origin + offset
	# Screen y grows downward; forward is up the screen.
	_vector = Vector2(offset.x, -offset.y) / radius


func release(index: int) -> void:
	if index != _touch_index:
		return
	_touch_index = -1
	_vector = Vector2.ZERO
	moved.emit(_vector)


## The half of the screen this joystick answers to.
func owns_point(position: Vector2) -> bool:
	var midpoint := size.x * 0.5
	return position.x < midpoint if side == "left" else position.x >= midpoint
