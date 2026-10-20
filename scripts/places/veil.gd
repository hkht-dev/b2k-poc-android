## The Pool of Worlds: the fall through stars between the Grove and the
## Street, and the rise back home (GDD §3 Act 2 "Falling" and Act 5 "Rising",
## §3a Act 2, §5 "The Pool of Worlds", §10 Pool row).
##
## Not a Place: nothing walks here and nothing can be used. "Nothing but
## tilting the view" (§3a): the camera drifts on its own, a drag or the right
## stick tilts it, and that is all. A field of stars streams past (two
## MultiMesh segments leapfrogging, under 400 points, two draw calls), a few
## bubbles pass, the vignette drains to blue-black on the way down and warms
## to rose-gold on the way up, the Song loses an instrument at a time (or
## finds them again), and the player's own glow unravels (or returns). On the
## way down three short lines appear one at a time (§8 Scene B). After
## `seconds` the view goes black, the journey records the next place and
## Main swaps the scene: the same seam a door uses.
##
## No Skip is offered. After `early_end_after` seconds a touch held still for
## `hold_seconds` ends it (GDD §11: nobody is held in a cinematic they cannot
## leave); the view darkens while the finger is down, so the hold is its own
## feedback and no meter is drawn (docs/DECISIONS.md). Which way, where to and
## how long are exports: data on VeilDown.tscn and VeilUp.tscn, not literals.
extends Node3D

## The view has gone black; Main shows the next place (as a Place does).
signal place_requested(place_id: String, spawn_id: String)
## The sequence is over, early (held) or in its own time.
signal ended(early: bool)

const DIRECTION_DOWN := "down"
const SONG_DOWN := preload("res://assets/audio/song_layers_down.ogg")
const SONG_UP := preload("res://assets/audio/song_layers_up.ogg")
## GDD §10, Pool row: blue-black, nebula violet, star white; the Grove's
## rose-gold at the far end of the way up. No peacock blue, no magenta.
const NEBULA_VIOLET := Color(0.27, 0.21, 0.33)
const BLUE_BLACK := Color(0.02, 0.03, 0.09)
const ROSE_GOLD := Color(0.92, 0.64, 0.5)
## The player's own glow (GDD §10: the Grove form "glows from within").
const GLOW_WARM := Color(0.98, 0.82, 0.58)
const GLOW_ALPHA := 0.55
## The sky behind the stars follows the vignette, darker.
const BACKGROUND_SHARE := 0.35
## Stars: two segments of this many points share one mesh and leapfrog past
## the camera, so the field is endless at two draw calls.
const STARS_PER_SEGMENT := 180
const SEGMENT_HEIGHT := 60.0
const STAR_RADIUS_MIN := 4.0
const STAR_RADIUS_MAX := 28.0
const STAR_SCALE_MIN := 0.6
const STAR_SCALE_MAX := 1.8
const STAR_SEED := 108
## Metres per second the world streams past. Bubbles rise through water, so
## they pass faster than the stars on the way down and lag them on the way up.
const FALL_SPEED := 6.0
const BUBBLE_RISE := 1.6
const BUBBLE_RANGE := 14.0
const BUBBLE_RADIUS_MIN := 2.5
const BUBBLE_RADIUS_MAX := 7.0
## The camera's own slow sway: radians, seconds, and a slow turn in rad/s.
const DRIFT_YAW := 0.06
const DRIFT_PITCH := 0.04
const DRIFT_YAW_PERIOD := 11.0
const DRIFT_PITCH_PERIOD := 7.0
const DRIFT_TURN := 0.015
## Tilt by drag: the camera rig's convention (scripts/player/camera_rig.gd).
const DRAG_TO_RADIANS := 0.0042
const TILT_LIMIT := 0.7
## Looking a little down the fall, a little up the rise.
const BASE_PITCH := 0.25
## A finger that wanders this far is dragging, not holding (TouchControls' slop).
const HOLD_SLOP := 10.0
const END_FADE_SECONDS := 1.2
const CANCEL_FADE_SECONDS := 0.3
const LINE_FADE_SECONDS := 1.0
const LINE_HOLD_SECONDS := 3.2
## The lines fall between these shares of the sequence.
const LINES_FROM := 0.28
const LINES_TO := 0.82
## §A4: touch sensitivity is half the desktop default (as the Place has it).
const TOUCH_SENSITIVITY := 0.5
const DESKTOP_SENSITIVITY := 1.0
const SILENT_DB := -40.0
## The "contextual" action (E, gamepad A) stands in for a finger on desktop.
const ACTION_HOLD_INDEX := -2

@export_enum("down", "up") var direction := "down"
## The place the view opens on afterwards (data/places.json), and the spawn there.
@export var next_place := "street"
@export var next_spawn := ""
@export_range(1.0, 180.0, 0.5) var seconds := 90.0
## Before this long, a held touch does nothing.
@export_range(0.0, 120.0, 0.5) var early_end_after := 20.0
@export_range(0.1, 3.0, 0.1) var hold_seconds := 1.0
## String ids shown one at a time through the middle of the sequence (§8 Scene B).
@export var line_ids: PackedStringArray = []

var _elapsed := 0.0
var _ending := false
var _holding := false
var _hold_index := -1
var _hold_start := Vector2.ZERO
var _held := 0.0
var _yaw := 0.0
var _pitch := 0.0
var _sensitivity := DESKTOP_SENSITIVITY
var _invert_y := false
var _line_index := -1
var _rng := RandomNumberGenerator.new()
var _bubble_phase := PackedFloat32Array()
var _fade_tween: Tween = null
var _line_tween: Tween = null

@onready var _pivot: Node3D = %Pivot
@onready var _tilt: Node3D = %Tilt
@onready var _world: WorldEnvironment = %World
@onready var _segment_a: MultiMeshInstance3D = %SegmentA
@onready var _segment_b: MultiMeshInstance3D = %SegmentB
@onready var _bubbles: Node3D = %Bubbles
@onready var _song: AudioStreamPlayer = %Song
@onready var _vignette: ColorRect = %Vignette
@onready var _glow: ColorRect = %Glow
@onready var _line: Label = %Line
@onready var _controls: Control = %TouchControls
@onready var _fade: ColorRect = %Fade


func _ready() -> void:
	_apply_settings()
	_rng.seed = STAR_SEED
	_build_stars()
	_segment_a.position.y = 0.0
	_segment_b.position.y = -SEGMENT_HEIGHT * _flow()
	for i in _bubbles.get_child_count():
		_bubble_phase.append(_rng.randf() * TAU)
		_reset_bubble(i, true)
	_pivot.rotation.y = 0.0
	_tilt.rotation.x = -BASE_PITCH * _flow()
	_hide_hud()
	_controls.camera_dragged.connect(_on_camera_dragged)
	_glow.color = GLOW_WARM
	_apply_colours(0.0)
	_line.text = ""
	_line.modulate.a = 0.0
	# The place before this one faded to black; the stars come out of it.
	_fade.color = Color(0.0, 0.0, 0.0, 1.0)
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade, "color:a", 0.0, END_FADE_SECONDS)
	_song.stream = SONG_DOWN if is_down() else SONG_UP
	_song.play()


func _process(delta: float) -> void:
	if _ending:
		return
	_elapsed += delta
	var p := progress()
	_apply_colours(p)
	_stream(delta)
	_drift()
	_show_lines(p)
	if _holding:
		_held += delta
		_fade.color.a = clampf(_held / hold_seconds, 0.0, 1.0)
		if _held >= hold_seconds:
			_finish(true)
			return
	if _elapsed >= seconds:
		_finish(false)


func _unhandled_input(event: InputEvent) -> void:
	if _ending:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_begin_hold(touch.index, touch.position)
		elif touch.index == _hold_index:
			_cancel_hold()
	elif event is InputEventScreenDrag and _holding:
		var drag := event as InputEventScreenDrag
		if drag.index == _hold_index and drag.position.distance_to(_hold_start) > HOLD_SLOP:
			_cancel_hold()
	elif event.is_action_pressed("contextual"):
		_begin_hold(ACTION_HOLD_INDEX, Vector2.ZERO)
	elif event.is_action_released("contextual") and _hold_index == ACTION_HOLD_INDEX:
		_cancel_hold()


# -- what the tests and the HUD read ------------------------------------------


func is_down() -> bool:
	return direction == DIRECTION_DOWN


## 0 at the start, 1 at the end.
func progress() -> float:
	return clampf(_elapsed / seconds, 0.0, 1.0)


func elapsed() -> float:
	return _elapsed


func is_ending() -> bool:
	return _ending


func is_holding() -> bool:
	return _holding


func can_end_early() -> bool:
	return _elapsed >= early_end_after and not _ending


func vignette_color() -> Color:
	return _vignette.color


func glow_alpha() -> float:
	return _glow.color.a


func fade_alpha() -> float:
	return _fade.color.a


## The player's own tilt, without the drift.
func camera_yaw() -> float:
	return _yaw


func camera_pitch() -> float:
	return _pitch


func star_count() -> int:
	return _segment_a.multimesh.instance_count * 2


## Where the two star segments are, so a test can see the field move.
func segment_heights() -> PackedFloat32Array:
	return PackedFloat32Array([_segment_a.position.y, _segment_b.position.y])


func controls() -> Control:
	return _controls


func current_line_id() -> String:
	return line_ids[_line_index] if _line_index >= 0 else ""


func line_text() -> String:
	return _line.text


# -- the fall -----------------------------------------------------------------


## +1 falling (the world streams up past the camera), -1 rising.
func _flow() -> float:
	return 1.0 if is_down() else -1.0


func _start_colour() -> Color:
	return NEBULA_VIOLET if is_down() else BLUE_BLACK


func _end_colour() -> Color:
	return BLUE_BLACK if is_down() else ROSE_GOLD


## The vignette, the sky behind the stars and the glow, all from one share.
func _apply_colours(p: float) -> void:
	var s := p * p * (3.0 - 2.0 * p)
	var colour := _start_colour().lerp(_end_colour(), s)
	_vignette.color = colour
	var sky := colour * BACKGROUND_SHARE
	sky.a = 1.0
	_world.environment.background_color = sky
	_glow.color.a = GLOW_ALPHA * ((1.0 - s) if is_down() else s)


func _stream(delta: float) -> void:
	var step := FALL_SPEED * delta * _flow()
	for segment: MultiMeshInstance3D in [_segment_a, _segment_b]:
		segment.position.y += step
		if segment.position.y * _flow() >= SEGMENT_HEIGHT:
			segment.position.y -= 2.0 * SEGMENT_HEIGHT * _flow()
	var rise := FALL_SPEED * _flow() + BUBBLE_RISE
	for i in _bubbles.get_child_count():
		var bubble := _bubbles.get_child(i) as Node3D
		_bubble_phase[i] += delta * 0.8
		bubble.position.y += rise * delta
		bubble.position.x += sin(_bubble_phase[i]) * 0.3 * delta
		if absf(bubble.position.y) > BUBBLE_RANGE:
			_reset_bubble(i, false)


func _drift() -> void:
	var sway_yaw := sin(_elapsed * TAU / DRIFT_YAW_PERIOD) * DRIFT_YAW + _elapsed * DRIFT_TURN
	var sway_pitch := sin(_elapsed * TAU / DRIFT_PITCH_PERIOD) * DRIFT_PITCH
	_pivot.rotation.y = _yaw + sway_yaw
	_tilt.rotation.x = -BASE_PITCH * _flow() + _pitch + sway_pitch


func _on_camera_dragged(delta: Vector2) -> void:
	if _ending:
		return
	_yaw -= delta.x * DRAG_TO_RADIANS * _sensitivity
	var vertical := delta.y * DRAG_TO_RADIANS * _sensitivity
	_pitch += vertical if _invert_y else -vertical
	_pitch = clampf(_pitch, -TILT_LIMIT, TILT_LIMIT)


## Each line has its share of the middle of the sequence; it fades in, holds
## and fades out, and the next waits its turn.
func _show_lines(p: float) -> void:
	var count := line_ids.size()
	if count == 0 or _line_index + 1 >= count:
		return
	var next := _line_index + 1
	var starts_at := LINES_FROM + (LINES_TO - LINES_FROM) * float(next) / float(count)
	if p < starts_at:
		return
	_line_index = next
	_line.text = Strings.t(line_ids[next])
	var window := seconds * (LINES_TO - LINES_FROM) / float(count)
	var hold := minf(LINE_HOLD_SECONDS, window * 0.5)
	var fade := minf(LINE_FADE_SECONDS, window * 0.2)
	if _line_tween != null and _line_tween.is_valid():
		_line_tween.kill()
	_line.modulate.a = 0.0
	_line_tween = create_tween()
	_line_tween.tween_property(_line, "modulate:a", 1.0, fade)
	_line_tween.tween_interval(hold)
	_line_tween.tween_property(_line, "modulate:a", 0.0, fade)


# -- the early end ------------------------------------------------------------


func _begin_hold(index: int, position: Vector2) -> void:
	if _holding or not can_end_early():
		return
	_holding = true
	_hold_index = index
	_hold_start = position
	_held = 0.0
	_kill_fade_tween()


func _cancel_hold() -> void:
	if not _holding:
		return
	_holding = false
	_hold_index = -1
	_kill_fade_tween()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade, "color:a", 0.0, CANCEL_FADE_SECONDS)


func _kill_fade_tween() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null


## The view goes black (from wherever the hold left it), the Song goes quiet,
## then the journey moves on and Main is asked for the next place.
func _finish(early: bool) -> void:
	if _ending:
		return
	_ending = true
	_holding = false
	_kill_fade_tween()
	var left := maxf(END_FADE_SECONDS * (1.0 - _fade.color.a), 0.1)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_fade, "color:a", 1.0, left)
	tween.tween_property(_song, "volume_db", SILENT_DB, left)
	tween.chain().tween_callback(_leave.bind(early))


func _leave(early: bool) -> void:
	GameState.set_place(next_place, next_spawn)
	ended.emit(early)
	place_requested.emit(next_place, next_spawn)


# -- setup --------------------------------------------------------------------


## The HUD is empty here (GDD §11): no joystick, no button, no pause, no
## map, no compass. The controls stay for the one thing they do here, the
## drag and the right stick that tilt the view.
func _hide_hud() -> void:
	_controls.joystick().visible = false
	_controls.contextual_button().visible = false
	_controls.pause_button().visible = false
	_controls.minimap().visible = false
	_controls.compass().visible = false


## §A6: the camera settings live in the journey, as the Place reads them.
func _apply_settings() -> void:
	var settings: Dictionary = GameState.settings
	var touch := DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	var default_sensitivity := TOUCH_SENSITIVITY if touch else DESKTOP_SENSITIVITY
	_sensitivity = float(settings.get("camera_sensitivity", default_sensitivity))
	_invert_y = bool(settings.get("camera_invert_y", false))


## One field of points in a ring around the camera's axis, uniform over the
## ring's area and the segment's height; both segments show the same one.
func _build_stars() -> void:
	var field: MultiMesh = _segment_a.multimesh
	field.instance_count = STARS_PER_SEGMENT
	var min_sq := STAR_RADIUS_MIN * STAR_RADIUS_MIN
	var max_sq := STAR_RADIUS_MAX * STAR_RADIUS_MAX
	for i in STARS_PER_SEGMENT:
		var angle := _rng.randf() * TAU
		var radius := sqrt(_rng.randf_range(min_sq, max_sq))
		var height := _rng.randf_range(-SEGMENT_HEIGHT * 0.5, SEGMENT_HEIGHT * 0.5)
		var size := _rng.randf_range(STAR_SCALE_MIN, STAR_SCALE_MAX)
		var basis := Basis.IDENTITY.scaled(Vector3.ONE * size)
		var origin := Vector3(cos(angle) * radius, height, sin(angle) * radius)
		field.set_instance_transform(i, Transform3D(basis, origin))
		# Star white with a little of the nebula's violet; never warm (GDD §10).
		var tint := Color.WHITE.lerp(NEBULA_VIOLET.lightened(0.5), _rng.randf() * 0.5)
		tint.a = _rng.randf_range(0.55, 1.0)
		field.set_instance_color(i, tint)
	_segment_b.multimesh = field


## A bubble somewhere around the camera, or at the edge it comes in from.
func _reset_bubble(i: int, anywhere: bool) -> void:
	var bubble := _bubbles.get_child(i) as Node3D
	var angle := _rng.randf() * TAU
	var radius := _rng.randf_range(BUBBLE_RADIUS_MIN, BUBBLE_RADIUS_MAX)
	var height := _rng.randf_range(-BUBBLE_RANGE, BUBBLE_RANGE)
	if not anywhere:
		# Bubbles move up past the camera on the way down and down on the way up.
		var rising := FALL_SPEED * _flow() + BUBBLE_RISE > 0.0
		height = -BUBBLE_RANGE if rising else BUBBLE_RANGE
	bubble.position = Vector3(cos(angle) * radius, height, sin(angle) * radius)
	bubble.scale = Vector3.ONE * _rng.randf_range(0.6, 1.4)
