## The traveler. Walks, runs after a held full tilt, and climbs ledges without
## a jump button.
##
## GDD §6 "Movement and camera": left-thumb joystick, auto-run after 0.5 s of
## full tilt, context-sensitive climb, no jump. The movement vector arrives
## already camera-relative from [member input_source]; this script never reads
## the camera, so the two can be tested apart.
extends CharacterBody3D

## Emitted when a climb starts and again when it ends, so the camera and the
## touch controls can step out of the way without polling.
signal climb_started
signal climb_finished

const WALK_SPEED := 2.2
const RUN_SPEED := 4.6
## Seconds of sustained full tilt before the walk becomes a run (GDD §6).
const AUTO_RUN_DELAY := 0.5
## Tilt magnitude that counts as "full" for the auto-run timer.
const FULL_TILT := 0.9
const ACCELERATION := 12.0
const TURN_SPEED := 9.0
const GRAVITY := 18.0
## How long a ledge climb takes, start to finish.
const CLIMB_DURATION := 0.85

var _move_input := Vector2.ZERO
var _full_tilt_time := 0.0
var _is_running := false
var _climb_from := Vector3.ZERO
var _climb_to := Vector3.ZERO
var _climb_elapsed := 0.0
var _is_climbing := false


func _physics_process(delta: float) -> void:
	if _is_climbing:
		_advance_climb(delta)
		return
	_advance_ground(delta)


## Sets this frame's movement wish, already rotated into world space by the
## caller. Length above 1 is clamped, so a caller cannot speed the player up.
func set_move_input(input: Vector2) -> void:
	_move_input = input if input.length() <= 1.0 else input.normalized()


func is_running() -> bool:
	return _is_running


func is_climbing() -> bool:
	return _is_climbing


## Starts a scripted climb to [param exit]. Ignored while one is already
## running, so overlapping ledge volumes cannot stack climbs.
func begin_climb(exit: Vector3) -> bool:
	if _is_climbing:
		return false
	_is_climbing = true
	_climb_from = global_position
	_climb_to = exit
	_climb_elapsed = 0.0
	_full_tilt_time = 0.0
	_is_running = false
	velocity = Vector3.ZERO
	climb_started.emit()
	return true


func _advance_ground(delta: float) -> void:
	var wish := Vector3(_move_input.x, 0.0, _move_input.y)
	var tilt := _move_input.length()

	if tilt >= FULL_TILT:
		_full_tilt_time += delta
	else:
		_full_tilt_time = 0.0
	_is_running = _full_tilt_time >= AUTO_RUN_DELAY

	var speed := RUN_SPEED if _is_running else WALK_SPEED
	var target := wish * speed * tilt
	velocity.x = move_toward(velocity.x, target.x, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, target.z, ACCELERATION * delta)

	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta

	if wish.length() > 0.01:
		# A Node3D's forward is -Z, so the angle that aims -Z along `wish` is
		# atan2 of its negation. Using atan2(wish.x, wish.z) would face away.
		var facing := atan2(-wish.x, -wish.z)
		rotation.y = lerp_angle(rotation.y, facing, TURN_SPEED * delta)

	move_and_slide()


## Moves the body along the climb arc. The lift happens before the forward
## travel, so the capsule clears the lip instead of shearing through it.
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
