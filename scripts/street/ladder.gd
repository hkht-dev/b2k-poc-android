## A ladder, climbed one segment at a time by walking into it.
##
## GDD §6: "approach a ledge or ladder and the character climbs; no jump
## button." GDD §3a, §5: the billboard tower is climbed by a ladder with four
## landings. Each segment is one of these areas on a landing, facing the
## rungs; a body in it moving toward them is carried to the next landing's
## exit marker by the player's own climb (`begin_climb`, as the fountain's
## ledge uses in scripts/street/climb_point.gd). Holding the stick toward the
## wall chains the segments; letting go rests on a landing. There is no
## climbing down: a landing's open side is a drop, and a drop costs nothing.
##
## The way in is this node's facing, not the exit's position: the exit is
## straight up, so its position says nothing about which way is "in".
extends Area3D

## A body set off up this segment.
signal climbed(body: CharacterBody3D)

const GROUP := "ladder"
## How squarely the body must be moving into the rungs: 1.0 is dead on,
## 0.0 is along the wall.
const FACING_TOLERANCE := 0.35
## Slower than this is standing on the landing, not walking into the ladder.
const MIN_SPEED := 0.2

## Where the segment ends: the landing above.
@export var exit_marker_path: NodePath

var _waiting: Array[CharacterBody3D] = []

@onready var _exit: Node3D = get_node_or_null(exit_marker_path) as Node3D


func _ready() -> void:
	add_to_group(GROUP)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if _exit == null:
		push_error("Ladder '%s' has no exit marker; it can never be climbed" % name)


func _physics_process(_delta: float) -> void:
	if _exit == null:
		return
	for body: CharacterBody3D in _waiting:
		if not is_instance_valid(body) or body.is_climbing():
			continue
		if _is_heading_in(body) and body.begin_climb(_exit.global_position):
			climbed.emit(body)


## The way into the rungs: this node's forward, flattened to the ground.
func into() -> Vector3:
	var forward := -global_transform.basis.z
	forward.y = 0.0
	return forward.normalized()


func exit_position() -> Vector3:
	return _exit.global_position if _exit != null else global_position


## True when the body is walking into the rungs rather than along the wall.
func _is_heading_in(body: CharacterBody3D) -> bool:
	var flat := Vector3(body.velocity.x, 0.0, body.velocity.z)
	if flat.length() < MIN_SPEED:
		return false
	return flat.normalized().dot(into()) >= FACING_TOLERANCE


func _on_body_entered(body: Node3D) -> void:
	var character := body as CharacterBody3D
	if character != null and character.has_method("begin_climb"):
		_waiting.append(character)


func _on_body_exited(body: Node3D) -> void:
	var character := body as CharacterBody3D
	if character != null:
		_waiting.erase(character)
