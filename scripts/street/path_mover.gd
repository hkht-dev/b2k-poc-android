## Moves a prop along a fixed loop of points, and yields to the player.
##
## Drives the street's ambience: pedestrians and vehicles on loops
## (CLAUDE_CODE_BRIEF.md §4.1). Not a navigation agent — no pathfinding, no
## route changes — but after the P2 playtest ("people and cars pass through
## me") each mover stops when the player stands in its way and goes on when
## they move, and carries a collision body so it cannot be walked through.
## It still never speaks, follows or notices the player beyond that.
extends Node3D

const PLAYER_GROUP := "player"
const YIELD_RAMP := 4.0

@export var points: PackedVector3Array = PackedVector3Array()
@export_range(0.2, 12.0, 0.1) var speed := 1.3
@export var face_travel := true
@export_range(0.0, 20.0, 0.1) var start_offset := 0.0
## How far ahead the mover looks for the player before stopping. A person
## stops close; a vehicle brakes early.
@export_range(0.0, 20.0, 0.1) var yield_distance := 1.6
## Half-width of the lane the mover yields in, in metres.
@export_range(0.0, 6.0, 0.1) var yield_width := 0.9

var _distance := 0.0
var _lengths: PackedFloat32Array = PackedFloat32Array()
var _total := 0.0
var _heading := Vector3.FORWARD
var _current_speed := 0.0


func _ready() -> void:
	_measure()
	_distance = start_offset
	_current_speed = speed
	if _total > 0.0:
		_place()


func _process(delta: float) -> void:
	if _total <= 0.0:
		return
	var wanted := 0.0 if _player_in_the_way() else speed
	_current_speed = move_toward(_current_speed, wanted, speed * YIELD_RAMP * delta)
	_distance = fmod(_distance + _current_speed * delta, _total)
	_place()


func is_yielding() -> bool:
	return _current_speed < speed * 0.5 and _player_in_the_way()


## True when the player stands inside the lane ahead.
func _player_in_the_way() -> bool:
	if yield_distance <= 0.0:
		return false
	var players := get_tree().get_nodes_in_group(PLAYER_GROUP)
	if players.is_empty():
		return false
	var player: Node3D = players[0]
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var ahead := to_player.dot(_heading)
	if ahead < 0.0 or ahead > yield_distance:
		return false
	var side := to_player.length_squared() - ahead * ahead
	return side <= yield_width * yield_width


func _measure() -> void:
	_lengths = PackedFloat32Array()
	_total = 0.0
	if points.size() < 2:
		return
	for i in points.size():
		var length := points[i].distance_to(points[(i + 1) % points.size()])
		_lengths.append(length)
		_total += length


func _place() -> void:
	var walked := _distance
	for i in _lengths.size():
		if walked <= _lengths[i]:
			var from := points[i]
			var to := points[(i + 1) % points.size()]
			var t: float = walked / maxf(_lengths[i], 0.0001)
			position = from.lerp(to, t)
			if from.distance_to(to) > 0.01:
				_heading = (to - from).normalized()
				if face_travel:
					# -Z is forward, as for the player and Tulu: a body on this
					# node walks the way it faces, not backwards.
					rotation.y = atan2(-_heading.x, -_heading.z)
			return
		walked -= _lengths[i]
