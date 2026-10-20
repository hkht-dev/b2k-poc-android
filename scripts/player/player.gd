## The traveler. Walks, runs after a held full push, walks to a tapped point,
## and climbs ledges without a jump button.
##
## GDD §6 "Movement and camera" and docs/BRIEF_AMENDMENT_1.md §A2–A3: auto-run
## at 85% deflection after 0.5 s; tap-to-walk steers to a point until the
## stick takes over. The movement vector arrives already camera-relative from
## the street; this script never reads the camera.
##
## The body wears the journey's outfit (GameState.outfit, data/outfits.json;
## owner request 2026-10-20, the showroom's wardrobe) and repaints when it
## changes, so a choice shows at once and a loaded journey comes back dressed.
extends CharacterBody3D

signal climb_started
signal climb_finished
## The first time the player moves under their own input. The hint listens.
signal moved_first_time

const WALK_SPEED := 2.2
const RUN_SPEED := 4.6
const AUTO_RUN_DELAY := 0.5
## Raw deflection that counts as a full push for the run timer (§A2).
const FULL_TILT := 0.85
const ACCELERATION := 12.0
const TURN_SPEED := 9.0
const GRAVITY := 18.0
const CLIMB_DURATION := 0.85
## Tap-to-walk arrives within this of the point and stops (§A3).
const ARRIVE_DISTANCE := 0.45
## Highest ledge the feet walk straight over: kerbs (0.16 m) and the fountain
## coping, but not a wall. A CharacterBody3D has no step-up of its own, and
## without this the kerb between pavement and road is a wall.
const STEP_HEIGHT := 0.36
## What the player carries persists as a flag `carrying_<item>` (GDD §12: the
## flag model is the only state), so an autosave mid-carry comes back with
## the item in hand. Which items exist, and what they look like, is data on
## the scene (`carryables`).
const CARRY_PREFIX := "carrying_"
const DEFAULT_ITEM := "can"
## PLACEHOLDER: four synthesised steps from tools/audio_parts/world.py,
## replaced by recorded steps per surface (GDD §10 "Sound"). One loop; the
## pitch tells a walk from a run, so there is nothing to cross-fade.
const FOOTSTEPS := preload("res://assets/audio/footsteps_pavement.ogg")
const FOOTSTEPS_WALK_PITCH := 1.0
const FOOTSTEPS_RUN_PITCH := 1.35
## Horizontal speed, m/s, below which the feet are still.
const FOOTSTEPS_MIN_SPEED := 0.3

## item id -> the scene shown in the hand (CLAUDE_CODE_BRIEF.md §4.4, §4.5).
@export var carryables: Dictionary = {}

var _move_input := Vector2.ZERO
var _deflection := 0.0
var _full_tilt_time := 0.0
var _is_running := false
var _run_time := 0.0
var _climb_from := Vector3.ZERO
var _climb_to := Vector3.ZERO
var _climb_elapsed := 0.0
var _is_climbing := false
var _walk_target := Vector3.ZERO
var _has_walk_target := false
var _has_moved := false
## Standing on the fitting dais with the wardrobe open: input is ignored.
var _still := false
## The skin the scene gave the body, worn when the journey names no outfit.
var _scene_skin: Texture2D = null
var _footsteps: AudioStreamPlayer3D = null

@onready var _rig: CharacterRig = %Mesh


func _ready() -> void:
	_footsteps = AudioStreamPlayer3D.new()
	_footsteps.stream = FOOTSTEPS
	_footsteps.volume_db = -6.0
	_footsteps.unit_size = 3.0
	_footsteps.max_distance = 16.0
	add_child(_footsteps)
	for item in carryables:
		if GameState.has_flag(CARRY_PREFIX + str(item)):
			_rig.carry(true, carryables[item])
			break
	_scene_skin = _rig.skin
	apply_outfit()
	GameState.outfit_changed.connect(_on_outfit_changed)


func _physics_process(delta: float) -> void:
	if _is_climbing:
		_advance_climb(delta)
		return
	if _still:
		return
	_advance_ground(delta)


## Dresses the body in the journey's outfit. An empty id, or one the data
## no longer knows, is the scene's own skin.
func apply_outfit() -> void:
	var texture: Texture2D = Outfits.skin_of(GameState.outfit)
	_rig.set_skin(texture if texture != null else _scene_skin)


## Holds the body where it stands (trying clothes on): the stick, the keys
## and a tap still arrive and do nothing until released.
func hold_still(on: bool) -> void:
	_still = on
	if on:
		velocity = Vector3.ZERO
		_has_walk_target = false


func is_held_still() -> bool:
	return _still


func _on_outfit_changed(_outfit_id: String) -> void:
	apply_outfit()


## Picks up an item: its flag is set and the body shows it in hand. One
## thing at a time; a second pick-up is refused.
func carry(item: String = DEFAULT_ITEM) -> bool:
	if is_carrying() or not carryables.has(item):
		return false
	GameState.set_flag(CARRY_PREFIX + item)
	_rig.carry(true, carryables[item])
	return true


## Whatever is in the hand leaves it (placed, or taken away by a scene).
func put_down() -> void:
	for item in carryables:
		GameState.clear_flag(CARRY_PREFIX + str(item))
	_rig.carry(false)


## Carrying `item`, or, with no item named, carrying anything.
func is_carrying(item: String = "") -> bool:
	if not item.is_empty():
		return GameState.has_flag(CARRY_PREFIX + item)
	for each in carryables:
		if GameState.has_flag(CARRY_PREFIX + str(each)):
			return true
	return false


func carried_item() -> String:
	for each in carryables:
		if GameState.has_flag(CARRY_PREFIX + str(each)):
			return str(each)
	return ""


## Sets this frame's movement wish (camera-relative, curved) and the raw
## deflection behind it. Any stick input cancels a tap-to-walk.
func set_move_input(input: Vector2, deflection: float = -1.0) -> void:
	_move_input = input if input.length() <= 1.0 else input.normalized()
	_deflection = clampf(deflection if deflection >= 0.0 else _move_input.length(), 0.0, 1.0)
	if _move_input.length() > 0.01:
		_has_walk_target = false


## Walks to a point on the ground, at walking pace, until arrival or until
## the stick takes over (§A3).
func walk_to(target: Vector3) -> void:
	_walk_target = Vector3(target.x, global_position.y, target.z)
	_has_walk_target = true


func is_walking_to() -> bool:
	return _has_walk_target


func is_running() -> bool:
	return _is_running


## Seconds of continuous running, for the camera's auto-align (§A4).
func run_time() -> float:
	return _run_time


func is_climbing() -> bool:
	return _is_climbing


func has_moved() -> bool:
	return _has_moved


## The feet are sounding: the body is moving over the ground.
func is_footsteps_playing() -> bool:
	return _footsteps.playing


## The footsteps' pitch: FOOTSTEPS_WALK_PITCH or FOOTSTEPS_RUN_PITCH.
func footsteps_pitch() -> float:
	return _footsteps.pitch_scale


func begin_climb(exit: Vector3) -> bool:
	if _is_climbing:
		return false
	_is_climbing = true
	_climb_from = global_position
	_climb_to = exit
	_climb_elapsed = 0.0
	_full_tilt_time = 0.0
	_is_running = false
	_run_time = 0.0
	_has_walk_target = false
	velocity = Vector3.ZERO
	_update_footsteps()
	climb_started.emit()
	return true


func _advance_ground(delta: float) -> void:
	var wish := Vector3(_move_input.x, 0.0, _move_input.y)
	var strength := _move_input.length()
	var deflection := _deflection

	if _has_walk_target and strength < 0.01:
		var to_target := _walk_target - global_position
		to_target.y = 0.0
		if to_target.length() <= ARRIVE_DISTANCE:
			_has_walk_target = false
		else:
			wish = to_target.normalized()
			strength = 1.0
			deflection = 0.0

	if deflection >= FULL_TILT:
		_full_tilt_time += delta
	else:
		_full_tilt_time = 0.0
	_is_running = _full_tilt_time >= AUTO_RUN_DELAY
	_run_time = _run_time + delta if _is_running else 0.0

	var speed := RUN_SPEED if _is_running else WALK_SPEED
	var target := wish.normalized() * speed * strength if wish.length() > 0.001 else Vector3.ZERO
	velocity.x = move_toward(velocity.x, target.x, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, target.z, ACCELERATION * delta)

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta

	if wish.length() > 0.01:
		var facing := atan2(-wish.x, -wish.z)
		rotation.y = lerp_angle(rotation.y, facing, TURN_SPEED * delta)
		if not _has_moved:
			_has_moved = true
			moved_first_time.emit()

	_step_up(delta)
	move_and_slide()
	_update_footsteps()


## The steps loop while the body actually moves (the velocity after sliding,
## so pushing at a wall is silent), faster when running, and stop when still
## or climbing.
func _update_footsteps() -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if not _is_climbing and speed >= FOOTSTEPS_MIN_SPEED:
		_footsteps.pitch_scale = FOOTSTEPS_RUN_PITCH if _is_running else FOOTSTEPS_WALK_PITCH
		if not _footsteps.playing:
			_footsteps.play()
	elif _footsteps.playing:
		_footsteps.stop()


## Lifts the body over a low ledge in its path. Three sweeps: is the way
## ahead blocked, is there room above, and is the way clear once raised. Only
## then does it rise; floor snapping settles it onto the ledge.
func _step_up(delta: float) -> void:
	if not is_on_floor():
		return
	var motion := Vector3(velocity.x, 0.0, velocity.z) * delta
	if motion.length() < 0.0005:
		return
	if not test_move(global_transform, motion):
		return
	var lift := Vector3.UP * STEP_HEIGHT
	if test_move(global_transform, lift):
		return
	if test_move(global_transform.translated(lift), motion):
		return
	global_position += lift


func _advance_climb(delta: float) -> void:
	_climb_elapsed += delta
	var t: float = clampf(_climb_elapsed / CLIMB_DURATION, 0.0, 1.0)
	var flat := Vector3(_climb_from.x, 0.0, _climb_from.z).lerp(
		Vector3(_climb_to.x, 0.0, _climb_to.z), smoothstep(0.35, 1.0, t)
	)
	var height: float = lerpf(_climb_from.y, _climb_to.y, smoothstep(0.0, 0.6, t))
	global_position = Vector3(flat.x, height, flat.z)
	if t >= 1.0:
		_is_climbing = false
		velocity = Vector3.ZERO
		climb_finished.emit()
