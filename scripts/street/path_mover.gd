## Moves a prop along a fixed loop of points at a constant speed.
##
## Drives the street's ambience: pedestrians who never react to the player and
## vehicles on a loop (CLAUDE_CODE_BRIEF.md §4.1, "Nothing is simulated").
## Deliberately not a navigation agent — there is no pathfinding, no avoidance
## and no awareness of the player, because the street is set dressing.
extends Node3D

@export var points: PackedVector3Array = PackedVector3Array()
@export_range(0.2, 12.0, 0.1) var speed := 1.3
## Turn toward the direction of travel. Vehicles want this; a pedestrian
## capsule with no front does not care.
@export var face_travel := true
@export_range(0.0, 20.0, 0.1) var start_offset := 0.0

var _distance := 0.0
var _lengths: PackedFloat32Array = PackedFloat32Array()
var _total := 0.0


func _ready() -> void:
	_measure()
	_distance = start_offset
	if _total > 0.0:
		_place()


func _process(delta: float) -> void:
	if _total <= 0.0:
		return
	_distance = fmod(_distance + speed * delta, _total)
	_place()


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
			if face_travel and from.distance_to(to) > 0.01:
				var heading := to - from
				rotation.y = atan2(heading.x, heading.z)
			return
		walked -= _lengths[i]
