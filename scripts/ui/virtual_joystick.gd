## Left-thumb floating joystick: the first touch in the left zone spawns it
## under the finger and that finger owns movement until it lifts.
##
## docs/BRIEF_AMENDMENT_1.md §A1–A2: left 45% of the screen; 12% dead zone;
## cubic response; auto-run judged on raw deflection (85%), so the curve
## never hides a full push from the run timer. §A5: a soft pulsing hint in
## the zone until the player first moves, for at most 60 s.
extends Control

signal moved(vector: Vector2)

const FADE_SPEED := 6.0
const DEAD_ZONE := 0.12
## Fraction of the screen width the joystick zone owns (§A1).
const ZONE_FRACTION := 0.45
const HINT_SECONDS := 60.0
const HINT_PULSE_HZ := 0.8

@export_range(48.0, 220.0, 1.0) var radius := 140.0
@export_range(0.1, 1.0, 0.05) var max_opacity := 0.4
@export_enum("left", "right") var side := "left"

var _touch_index := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO
var _vector := Vector2.ZERO
var _deflection := 0.0
var _shown := 0.0
var _hint_left := HINT_SECONDS
var _hint_text := ""
var _hint_font: Font = null
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_hint_text = Strings.t("controls.hint.walk")
	_hint_font = get_theme_default_font()


func _process(delta: float) -> void:
	_time += delta
	var wanted := 1.0 if _touch_index != -1 else 0.0
	_shown = move_toward(_shown, wanted, FADE_SPEED * delta)
	if _hint_left > 0.0:
		_hint_left = maxf(0.0, _hint_left - delta)
	queue_redraw()


func _draw() -> void:
	if _hint_left > 0.0 and _shown <= 0.01:
		var pulse := 0.5 + 0.5 * sin(_time * TAU * HINT_PULSE_HZ)
		var alpha := 0.10 + 0.14 * pulse
		var at := resting_position()
		var tint := Color(0.42, 0.31, 0.208, alpha)
		draw_arc(at, radius, 0.0, TAU, 48, tint, 3.0, true)
		draw_circle(at, radius * 0.32, tint)
		if _hint_font != null:
			var width := (
				_hint_font.get_string_size(_hint_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 20).x
			)
			draw_string(
				_hint_font,
				at + Vector2(-width * 0.5, radius + 44.0),
				_hint_text,
				HORIZONTAL_ALIGNMENT_CENTER,
				-1,
				20,
				Color(0.42, 0.31, 0.208, alpha * 2.2)
			)
		return
	if _shown <= 0.01:
		return
	var base := Color(0.42, 0.31, 0.208, max_opacity * _shown)
	var knob := Color(0.957, 0.925, 0.847, max_opacity * 2.0 * _shown)
	draw_arc(_origin, radius, 0.0, TAU, 48, base, 3.0, true)
	draw_circle(_knob, radius * 0.32, knob)


## The curved stick vector: x right, y forward. Length is the cubic of the
## raw deflection, so a gentle push creeps and a full push is full.
func vector() -> Vector2:
	return _vector


## Raw deflection after the dead zone, 0..1. The run timer reads this.
func deflection() -> float:
	return _deflection


func is_active() -> bool:
	return _touch_index != -1


## The player moved: the hint has done its job.
func dismiss_hint() -> void:
	_hint_left = 0.0


func hint_visible() -> bool:
	return _hint_left > 0.0


func try_claim(index: int, position: Vector2) -> bool:
	if _touch_index != -1 or not owns_point(position):
		return false
	_touch_index = index
	_origin = position
	_knob = position
	_vector = Vector2.ZERO
	_deflection = 0.0
	return true


func drag_to(index: int, position: Vector2) -> void:
	if index != _touch_index:
		return
	var offset := position - _origin
	if offset.length() > radius:
		offset = offset.normalized() * radius
	_knob = _origin + offset
	var raw := offset.length() / radius
	_deflection = clampf((raw - DEAD_ZONE) / (1.0 - DEAD_ZONE), 0.0, 1.0)
	var curved := _deflection * _deflection * _deflection
	var direction := Vector2.ZERO if offset.length() < 0.001 else offset.normalized()
	# Screen y grows downward; forward is up the screen.
	_vector = Vector2(direction.x, -direction.y) * curved
	moved.emit(_vector)


func release(index: int) -> void:
	if index != _touch_index:
		return
	_touch_index = -1
	_vector = Vector2.ZERO
	_deflection = 0.0
	moved.emit(_vector)


## The 45% of the screen this joystick answers to (§A1).
func owns_point(position: Vector2) -> bool:
	var edge := size.x * ZONE_FRACTION
	return position.x < edge if side == "left" else position.x >= size.x - edge


func resting_position() -> Vector2:
	var x := radius + 90.0 if side == "left" else size.x - radius - 90.0
	return Vector2(x, size.y - radius - 260.0)
