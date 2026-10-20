## A car the player can get into and drive about the Street.
##
## Owner request 2026-10-20 ("enter inside cars, drive"). GDD §6 names
## movement as the first of the five things the player does; this is movement
## at another pace and nothing more: no speedometer, no race, no damage, no
## fuel (CLAUDE.md: never a meter). *Drive* is an Interactable round the car;
## the Place base boards the player, feeds the stick here and gets them out
## again (scripts/places/place.gd, "driving"). Arcade kinematics: the stick's
## Y is the throttle, its X the wheel; steering bites with speed.
class_name DriveableCar
extends CharacterBody3D

## The player used *Drive*: the Place boards them.
signal board_requested(car: DriveableCar)

const GROUP := "driveable"
const WORLD_LAYER := 1
## Metres per second: the pace of a quiet street, not a chase.
const MAX_FORWARD := 11.0
const MAX_REVERSE := 3.0
## Metres per second squared: on the throttle, on the brake, coasting.
const THROTTLE_ACCELERATION := 6.0
const BRAKE_DECELERATION := 12.0
const COAST_DECELERATION := 3.0
## Yaw rate at full lock, radians per second, reached from this speed up;
## slower, the wheel turns the car in proportion, and a still car not at all.
const STEER_RATE := 1.5
const STEER_FULL_SPEED := 4.0
const GRAVITY := 18.0
## Kerbs (0.16 m) and the fountain's step are driven over; walls are not.
const STEP_HEIGHT := 0.25
## The engine's pitch at rest and at top speed (assets/audio/engine_loop.ogg).
const PITCH_IDLE := 0.8
const PITCH_TOP := 1.6
## Where the player stands on getting out: this far beside a door, in metres.
const DOOR_OFFSET := 1.7
## Below this the car counts as standing still.
const STILL := 0.05

## The verb the button shows while driving (data; the Place reads it).
@export var exit_verb_id := "verb.exit"

var _input := Vector2.ZERO
## Signed speed along the car's nose: forward positive.
var _speed := 0.0
var _driving := false

@onready var _enter: Interactable = %Enter
@onready var _engine: AudioStreamPlayer3D = %Engine


func _ready() -> void:
	add_to_group(GROUP)
	_enter.used.connect(_on_enter_used)
	_engine.pitch_scale = PITCH_IDLE


func _physics_process(delta: float) -> void:
	var throttle := clampf(_input.y, -1.0, 1.0) if _driving else 0.0
	var steer := clampf(_input.x, -1.0, 1.0) if _driving else 0.0
	_advance_speed(throttle, delta)
	if absf(_speed) > STILL:
		var lock := clampf(absf(_speed) / STEER_FULL_SPEED, 0.0, 1.0)
		# Right on the stick turns the nose right going forward (yaw falls);
		# backing up, the nose swings the other way, as a car's does.
		rotation.y -= steer * STEER_RATE * lock * signf(_speed) * delta
	var forward := -global_transform.basis.z
	velocity.x = forward.x * _speed
	velocity.z = forward.z * _speed
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	_step_up(delta)
	move_and_slide()
	if is_on_wall():
		# What the wall took, the car has lost: a head-on stop, or a scrape along.
		var kept := -get_real_velocity().dot(global_transform.basis.z)
		_speed = clampf(kept, -MAX_REVERSE, MAX_FORWARD)
	_engine.pitch_scale = lerpf(PITCH_IDLE, PITCH_TOP, clampf(absf(_speed) / MAX_FORWARD, 0.0, 1.0))


## This frame's stick, raw: Y forward and back, X left and right.
func set_drive_input(move: Vector2) -> void:
	_input = move


## The player is at the wheel: the stick reaches the car, the engine runs,
## and the car cannot be entered again until they get out.
func start_driving() -> void:
	_driving = true
	_enter.enabled = false
	_engine.play()


## The player got out. The car coasts to a stop on its own.
func stop_driving() -> void:
	_driving = false
	_input = Vector2.ZERO
	_enter.enabled = true
	_engine.stop()


func is_driving() -> bool:
	return _driving


## Signed speed along the nose in metres per second: forward positive. For
## the camera and the tests; nothing draws it (CLAUDE.md: no meter).
func speed() -> float:
	return _speed


## Rolling, as against standing. The camera eases round behind a rolling car.
func is_moving() -> bool:
	return absf(_speed) > 0.5


func enter_area() -> Interactable:
	return _enter


## Where the player stands on getting out: beside the left door, or the right
## one if something stands against the left.
func door_point() -> Vector3:
	var left := to_global(Vector3(-DOOR_OFFSET, 0.0, 0.0))
	if _is_clear_to(left):
		return left
	var right := to_global(Vector3(DOOR_OFFSET, 0.0, 0.0))
	if _is_clear_to(right):
		return right
	return left


func _is_clear_to(point: Vector3) -> bool:
	var from := global_position + Vector3.UP * 0.9
	var to := Vector3(point.x, from.y, point.z)
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_LAYER)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _advance_speed(throttle: float, delta: float) -> void:
	if absf(throttle) < STILL:
		# Off the throttle the car coasts; with nobody at the wheel it is parked.
		var slowing := COAST_DECELERATION if _driving else BRAKE_DECELERATION
		_speed = move_toward(_speed, 0.0, slowing * delta)
		return
	var top := MAX_FORWARD if throttle > 0.0 else MAX_REVERSE
	var braking := absf(_speed) > STILL and signf(throttle) != signf(_speed)
	var rate := BRAKE_DECELERATION if braking else THROTTLE_ACCELERATION
	_speed = move_toward(_speed, top * throttle, rate * delta)


## Lifts the body over a low ledge in its path: the player's three sweeps
## (scripts/player/player.gd), at a car's step height.
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


func _on_enter_used(_player: Node3D) -> void:
	if not _driving:
		board_requested.emit(self)
