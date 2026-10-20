## Third-person camera: lags the player by ~0.15 s, orbits by thumb, stick or
## mouse, widens at a run, bobs a little, and eases back behind the player
## after a sustained run with no drag.
##
## GDD §6 and docs/BRIEF_AMENDMENT_1.md §A4, §B6. The rig chases the player
## rather than parenting to it, so it keeps its own easing while the body
## turns underneath.
extends Node3D

## Seconds the rig trails the player (§B6: ~0.15 s).
const FOLLOW_LAG := 0.15
const DISTANCE := 3.5
const COLLISION_MARGIN := 0.35
const MIN_DISTANCE := 0.6
const DISTANCE_LERP := 10.0
const WORLD_LAYER := 1
const PITCH_MIN := -0.52
const PITCH_MAX := 0.42
const DRAG_TO_RADIANS := 0.0042
const SHOULDER_HEIGHT := 1.15
## Follow profiles: how far behind and how high the rig sits, and whether it
## eases round behind the target whenever it rolls. Walking is GDD §6's
## 3.5 m; a car (scripts/vehicles/car.gd) is seen from farther back and
## higher, and the view follows its nose round so steering reads.
const PROFILE_WALK := "walk"
const PROFILE_CAR := "car"
const PROFILES := {
	PROFILE_WALK: {"distance": DISTANCE, "height": SHOULDER_HEIGHT, "follow_turns": false},
	PROFILE_CAR: {"distance": 6.0, "height": 1.6, "follow_turns": true},
}
## §B6: 65 at a walk, 72 at a run.
const WALK_FOV := 65.0
const RUN_FOV := 72.0
const FOV_SPEED := 4.0
## Head-bob at a run: amplitude in metres and cycles per second.
const BOB_AMPLITUDE := 0.035
const BOB_HZ := 2.4
## §A4: running this long without a drag eases the camera back behind.
const AUTO_ALIGN_AFTER := 1.5
const AUTO_ALIGN_SPEED := 2.2

@export var target_path: NodePath
@export_range(0.1, 3.0, 0.05) var sensitivity := 1.0
@export var invert_y := false

var _yaw := 0.0
var _pitch := -0.18
var _distance := DISTANCE
var _bob_phase := 0.0
var _since_drag := 1000.0
var _drift_target := Vector3.ZERO
var _drift_left := 0.0
var _profile := PROFILE_WALK

@onready var _yaw_pivot: Node3D = $YawPivot
@onready var _pitch_pivot: Node3D = $YawPivot/PitchPivot
@onready var _camera: Camera3D = $YawPivot/PitchPivot/Camera


func _ready() -> void:
	_yaw_pivot.rotation.y = _yaw
	_pitch_pivot.rotation.x = _pitch
	var target := _target()
	if target != null:
		global_position = target.global_position + Vector3.UP * _follow_height()


func _physics_process(delta: float) -> void:
	var target := _target()
	if target == null:
		return
	_since_drag += delta
	var running: bool = target.has_method("is_running") and target.is_running()

	var bob := 0.0
	if running:
		_bob_phase = fmod(_bob_phase + delta * BOB_HZ * TAU, TAU)
		bob = sin(_bob_phase) * BOB_AMPLITUDE
	var wanted := target.global_position + Vector3.UP * (_follow_height() + bob)
	var follow := 1.0 - exp(-delta / FOLLOW_LAG)
	global_position = global_position.lerp(wanted, follow)

	if _drift_left > 0.0:
		_drift_left -= delta
		var to := _drift_target - global_position
		to.y = 0.0
		if to.length() > 0.1:
			# Put the camera on the far side of the player from the sound.
			var wanted_yaw := atan2(to.x, to.z) + PI
			_yaw = lerp_angle(_yaw, wanted_yaw, minf(1.0, 3.0 * delta))
			_yaw_pivot.rotation.y = _yaw

	var ran_long: bool = (
		running and target.has_method("run_time") and target.run_time() > AUTO_ALIGN_AFTER
	)
	var rolling: bool = _follows_turns() and target.has_method("is_moving") and target.is_moving()
	if (ran_long or rolling) and _since_drag > AUTO_ALIGN_AFTER:
		_yaw = lerp_angle(_yaw, target.rotation.y, minf(1.0, AUTO_ALIGN_SPEED * delta))
		_yaw_pivot.rotation.y = _yaw

	_pull_in_from_walls(delta)
	var fov := RUN_FOV if running else WALK_FOV
	_camera.fov = lerpf(_camera.fov, fov, minf(1.0, FOV_SPEED * delta))


func _pull_in_from_walls(delta: float) -> void:
	var pivot := _pitch_pivot.global_transform
	var query := PhysicsRayQueryParameters3D.create(
		pivot.origin, pivot * Vector3(0.0, 0.0, _follow_distance()), WORLD_LAYER
	)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var wanted := _follow_distance()
	if not hit.is_empty():
		wanted = maxf(MIN_DISTANCE, pivot.origin.distance_to(hit.position) - COLLISION_MARGIN)
	if wanted < _distance:
		_distance = wanted
	else:
		_distance = lerpf(_distance, wanted, minf(1.0, DISTANCE_LERP * delta))
	_camera.position.z = _distance


## Frames the walk or the car (PROFILES). A name not in the table walks.
func set_follow_profile(profile: String) -> void:
	_profile = profile if PROFILES.has(profile) else PROFILE_WALK


func follow_profile() -> String:
	return _profile


func _follow_distance() -> float:
	return float(PROFILES[_profile]["distance"])


func _follow_height() -> float:
	return float(PROFILES[_profile]["height"])


func _follows_turns() -> bool:
	return bool(PROFILES[_profile]["follow_turns"])


func camera_distance() -> float:
	return _distance


## Eases the camera round to face [param point] for [param seconds]
## (CLAUDE_CODE_BRIEF.md §4.3: *Listen* "drifts the camera toward him").
func drift_toward(point: Vector3, seconds: float = 1.5) -> void:
	_drift_target = point
	_drift_left = seconds


func is_drifting() -> bool:
	return _drift_left > 0.0


## Orbits by a drag delta in pixels and resets the auto-align timer.
func orbit(drag: Vector2) -> void:
	_since_drag = 0.0
	_drift_left = 0.0
	_yaw -= drag.x * DRAG_TO_RADIANS * sensitivity
	var vertical := drag.y * DRAG_TO_RADIANS * sensitivity
	_pitch += vertical if invert_y else -vertical
	_pitch = clampf(_pitch, PITCH_MIN, PITCH_MAX)
	_yaw_pivot.rotation.y = _yaw
	_pitch_pivot.rotation.x = _pitch


## Puts the camera straight behind a body facing [param yaw], at once: on
## arriving through a door the view should already look into the room.
func snap_behind(yaw: float) -> void:
	_yaw = yaw
	_yaw_pivot.rotation.y = _yaw
	_since_drag = 1000.0
	_drift_left = 0.0
	var target := _target()
	if target != null:
		global_position = target.global_position + Vector3.UP * _follow_height()


func stick_to_world(stick: Vector2) -> Vector2:
	return Vector2(stick.x, -stick.y).rotated(-_yaw)


## World point under a screen position on the ground, or null.
func ground_point(screen: Vector2) -> Variant:
	var from := _camera.project_ray_origin(screen)
	var to := from + _camera.project_ray_normal(screen) * 200.0
	var query := PhysicsRayQueryParameters3D.create(from, to, WORLD_LAYER)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null
	return hit.position


func get_yaw() -> float:
	return _yaw


func get_pitch() -> float:
	return _pitch


func camera() -> Camera3D:
	return _camera


func _target() -> Node3D:
	if target_path.is_empty():
		return null
	return get_node_or_null(target_path) as Node3D
