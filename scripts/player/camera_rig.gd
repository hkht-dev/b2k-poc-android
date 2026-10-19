## Soft-follow third-person camera, orbited by the right thumb.
##
## GDD §6 "Movement and camera": soft-follow third person at 3.5 m, right-thumb
## drag to orbit. The rig chases the player rather than parenting to it, so the
## camera keeps its own easing while the body turns underneath.
extends Node3D

const FOLLOW_SPEED := 7.0
## GDD §6: "soft-follow third person at 3.5 m".
const DISTANCE := 3.5
## Keeps the near plane out of the surface the camera backed into.
const COLLISION_MARGIN := 0.35
const MIN_DISTANCE := 0.6
const DISTANCE_LERP := 10.0
## Collision layer 1 is the world. The player is on layer 2 so the camera
## never pulls in on the body it is following.
const WORLD_LAYER := 1
const PITCH_MIN := -0.52
const PITCH_MAX := 0.42
## Radians of orbit per pixel of drag, before the sensitivity setting.
const DRAG_TO_RADIANS := 0.0042
## Height above the player's origin that the camera looks at.
const SHOULDER_HEIGHT := 1.15
## Field of view at a walk and at a run. The widening is the camera telling
## the body it is moving faster; it eases so it never pops.
const WALK_FOV := 62.0
const RUN_FOV := 70.0
const FOV_SPEED := 4.0

@export var target_path: NodePath
@export_range(0.25, 3.0, 0.05) var sensitivity := 1.0
@export var invert_y := false

var _yaw := 0.0
var _pitch := -0.18
var _distance := DISTANCE

@onready var _yaw_pivot: Node3D = $YawPivot
@onready var _pitch_pivot: Node3D = $YawPivot/PitchPivot
@onready var _camera: Camera3D = $YawPivot/PitchPivot/Camera


func _ready() -> void:
	_yaw_pivot.rotation.y = _yaw
	_pitch_pivot.rotation.x = _pitch
	var target := _target()
	if target != null:
		global_position = target.global_position + Vector3.UP * SHOULDER_HEIGHT


func _physics_process(delta: float) -> void:
	var target := _target()
	if target == null:
		return
	var wanted := target.global_position + Vector3.UP * SHOULDER_HEIGHT
	global_position = global_position.lerp(wanted, minf(1.0, FOLLOW_SPEED * delta))
	_pull_in_from_walls(delta)
	var running: bool = target.has_method("is_running") and target.is_running()
	var fov := RUN_FOV if running else WALK_FOV
	_camera.fov = lerpf(_camera.fov, fov, minf(1.0, FOV_SPEED * delta))


## Shortens the arm when a wall is between the pivot and the camera, so the
## view never ends up inside the fountain basin or a shopfront. Without this
## the opening shot renders from inside the basin wall.
func _pull_in_from_walls(delta: float) -> void:
	var pivot := _pitch_pivot.global_transform
	var query := PhysicsRayQueryParameters3D.create(
		pivot.origin, pivot * Vector3(0.0, 0.0, DISTANCE), WORLD_LAYER
	)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var wanted := DISTANCE
	if not hit.is_empty():
		wanted = maxf(MIN_DISTANCE, pivot.origin.distance_to(hit.position) - COLLISION_MARGIN)
	# Snap in immediately, ease back out: popping into a wall reads as a bug,
	# easing out of one reads as the camera breathing.
	if wanted < _distance:
		_distance = wanted
	else:
		_distance = lerpf(_distance, wanted, minf(1.0, DISTANCE_LERP * delta))
	_camera.position.z = _distance


func camera_distance() -> float:
	return _distance


## Orbits by a drag delta in pixels. Pitch is clamped so the camera can never
## look straight down the player's head or up into the sky.
func orbit(drag: Vector2) -> void:
	_yaw -= drag.x * DRAG_TO_RADIANS * sensitivity
	var vertical := drag.y * DRAG_TO_RADIANS * sensitivity
	_pitch += vertical if invert_y else -vertical
	_pitch = clampf(_pitch, PITCH_MIN, PITCH_MAX)
	_yaw_pivot.rotation.y = _yaw
	_pitch_pivot.rotation.x = _pitch


## Rotates a screen-space stick vector into world space, so "up" on the stick
## is always away from the camera. Returns (x, z) for a world-space
## [Vector3](x, 0, z): screen-up becomes -Z, which is forward in Godot.
func stick_to_world(stick: Vector2) -> Vector2:
	return Vector2(stick.x, -stick.y).rotated(-_yaw)


func get_yaw() -> float:
	return _yaw


func get_pitch() -> float:
	return _pitch


func _target() -> Node3D:
	if target_path.is_empty():
		return null
	return get_node_or_null(target_path) as Node3D
