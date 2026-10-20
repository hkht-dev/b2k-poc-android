## A lamp someone set down: a small clay light carrying one preset line.
##
## GDD §16a "Social: lamps": "Anywhere in the Street ... the player can set
## down a lamp with one of twelve preset lines ... Others see lamps as small
## lights, can sit by them and leave a flower." This build has no network, so
## every lamp here is the player's own, kept in the journey
## (GameState.lamps); the Place spawns one of these per record of its place.
## *Sit* shows the lamp's line as a subtitle (the Place does that) and sits
## the player in the bus stop's clip until they move, which this node watches
## for in the player's velocity. Other people's lamps, and the flower, are
## future work (docs/DECISIONS.md).
##
## PLACEHOLDER: the primitives (a low clay cylinder and a warm sphere for the
## flame) stand in for the hand-painted clay diya of GDD §10 and §16a.
class_name Lamp
extends Node3D

## The player sat by this lamp; `line_id` is its preset line.
signal sat(line_id: String)
## The player stood up again.
signal stood(line_id: String)

const SIT_POSE := "Sitting_Idle"
## Horizontal speed, in m/s, above which the sitter has moved.
const MOVING := 0.15
## How far above and below its own height the lamp looks for the ground.
const SETTLE_REACH := 2.0
## The world's collision layer; the player's (2) is not it.
const WORLD_MASK := 1

## This lamp's record in the journey: {place, x, z, line_id, lit_day}.
var lamp: Dictionary = {}

var _sitter: CharacterBody3D = null
var _settled := false

@onready var _sit: Interactable = %Sit
@onready var _light: OmniLight3D = %Light


func _ready() -> void:
	_sit.used.connect(_on_sit)


func _physics_process(_delta: float) -> void:
	if not _settled:
		_settle()
	_sit.enabled = _sitter == null
	if _sitter == null:
		return
	var flat := Vector3(_sitter.velocity.x, 0.0, _sitter.velocity.z)
	if flat.length() > MOVING:
		_stand()


func _exit_tree() -> void:
	if _sitter != null:
		_stand()


func line_id() -> String:
	return str(lamp.get("line_id", ""))


func is_sat() -> bool:
	return _sitter != null


func light() -> OmniLight3D:
	return _light


## Puts the lamp on the ground beneath its x, z. The record keeps no height,
## so a lamp set on a kerb sits on the kerb when it comes back.
func _settle() -> void:
	_settled = true
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	var reach := Vector3.UP * SETTLE_REACH
	var query := PhysicsRayQueryParameters3D.create(
		global_position + reach, global_position - reach, WORLD_MASK
	)
	var hit := space.intersect_ray(query)
	if hit.has("position"):
		global_position.y = (hit["position"] as Vector3).y


func _on_sit(player: Node3D) -> void:
	var body := player as CharacterBody3D
	if body == null or _sitter != null:
		return
	_sitter = body
	var rig := _rig_of(body)
	if rig != null:
		rig.hold_pose(SIT_POSE)
	sat.emit(line_id())


func _stand() -> void:
	var rig := _rig_of(_sitter)
	if rig != null:
		rig.release_pose()
	_sitter = null
	stood.emit(line_id())


static func _rig_of(body: Node) -> CharacterRig:
	if body == null or not is_instance_valid(body):
		return null
	return body.get_node_or_null("%Mesh") as CharacterRig
