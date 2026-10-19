## Procedural walk, run and idle for a simple humanoid made of primitives.
##
## docs/BRIEF_AMENDMENT_1.md §B4: characters are low-poly humanoids, not
## capsules, with walk and idle; CC0 rigs or a procedural bob are acceptable.
## This is the procedural bob. It reads movement from its own position delta,
## so it works for the player (a CharacterBody3D above it) and for pedestrians
## on paths alike, with no coupling to either.
extends Node3D

const STRIDE_HZ_PER_MS := 0.95
const SWING := 0.42
const ARM_SWING := 0.32
const BOB := 0.03
const IDLE_SWAY := 0.02
const LEAN_PER_MS := 0.025

var _phase := 0.0
var _last := Vector3.ZERO
var _speed := 0.0
var _time := 0.0

@onready var _torso: Node3D = get_node_or_null("Torso")
@onready var _left_arm: Node3D = get_node_or_null("LeftArm")
@onready var _right_arm: Node3D = get_node_or_null("RightArm")
@onready var _left_leg: Node3D = get_node_or_null("LeftLeg")
@onready var _right_leg: Node3D = get_node_or_null("RightLeg")


func _ready() -> void:
	_last = global_position


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_time += delta
	var moved := global_position - _last
	moved.y = 0.0
	_last = global_position
	var instant := moved.length() / delta
	_speed = lerpf(_speed, instant, minf(1.0, 10.0 * delta))

	if _speed > 0.15:
		_phase = fmod(_phase + delta * TAU * STRIDE_HZ_PER_MS * _speed, TAU)
		var swing := sin(_phase)
		_set_x(_left_leg, swing * SWING)
		_set_x(_right_leg, -swing * SWING)
		_set_x(_left_arm, -swing * ARM_SWING)
		_set_x(_right_arm, swing * ARM_SWING)
		if _torso != null:
			_torso.position.y = absf(sin(_phase * 2.0)) * BOB * minf(1.0, _speed / 2.0)
			_torso.rotation.x = -LEAN_PER_MS * _speed
	else:
		_phase = 0.0
		var sway := sin(_time * 1.3) * IDLE_SWAY
		_set_x(_left_leg, 0.0)
		_set_x(_right_leg, 0.0)
		_set_x(_left_arm, sway)
		_set_x(_right_arm, -sway)
		if _torso != null:
			_torso.position.y = lerpf(_torso.position.y, 0.0, minf(1.0, 6.0 * delta))
			_torso.rotation.x = lerpf(_torso.rotation.x, sway * 0.5, minf(1.0, 6.0 * delta))


func speed() -> float:
	return _speed


func _set_x(limb: Node3D, angle: float) -> void:
	if limb != null:
		limb.rotation.x = lerp_angle(limb.rotation.x, angle, 0.5)
