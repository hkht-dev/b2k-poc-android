## A ledge the player climbs by walking into it.
##
## GDD §6: "approach a ledge or ladder and the character climbs; no jump
## button." No prompt, no button — walking at the ledge is the whole input.
## The climb only fires when the player is actually heading into the ledge, so
## brushing past the fountain rim does not launch them over it.
extends Area3D

## How squarely the player must be moving into the ledge: 1.0 is dead on,
## 0.0 is sideways.
const FACING_TOLERANCE := 0.35

@export var exit_marker_path: NodePath

var _waiting: Array[CharacterBody3D] = []

@onready var _exit: Node3D = get_node_or_null(exit_marker_path) as Node3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if _exit == null:
		push_error("ClimbPoint '%s' has no exit marker; it can never be climbed" % name)


func _physics_process(_delta: float) -> void:
	if _exit == null:
		return
	for body: CharacterBody3D in _waiting:
		if not is_instance_valid(body) or body.is_climbing():
			continue
		if _is_heading_in(body):
			body.begin_climb(_exit.global_position)


## True when the body is moving into the ledge rather than along it.
func _is_heading_in(body: CharacterBody3D) -> bool:
	var flat := Vector3(body.velocity.x, 0.0, body.velocity.z)
	if flat.length() < 0.2:
		return false
	var toward := _exit.global_position - body.global_position
	toward.y = 0.0
	if toward.length() < 0.01:
		return true
	return flat.normalized().dot(toward.normalized()) >= FACING_TOLERANCE


func _on_body_entered(body: Node3D) -> void:
	var character := body as CharacterBody3D
	if character != null and character.has_method("begin_climb"):
		_waiting.append(character)


func _on_body_exited(body: Node3D) -> void:
	var character := body as CharacterBody3D
	if character != null:
		_waiting.erase(character)
