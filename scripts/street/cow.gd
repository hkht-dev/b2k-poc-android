## A stray cow: one of the Grove's, wandering Hollow Vale unseen.
##
## GDD §3a Act 3, "Walk ahead of two cows and hum to steer them through
## traffic" (*Stray cows*: "care for what nobody else sees"), and §16a
## "Stray cows": guiding them through traffic to the fountain is a
## timing-and-path puzzle. The slice has the puzzle's smallest form: two
## cows on the north pavement east of the fountain, the roads between.
##
## A cow grazes within a few metres of its home spot. The player's hum
## (Place.hum, through the `sound_source` group) calls it: it walks toward
## where the player stood, at most `CALL_REACH` metres, then settles there,
## so each hum is one leg of the path. It will not step off the pavement
## into a lane while a vehicle is near; once in the road it keeps walking
## until it is out again, and the traffic yields to it
## (scripts/street/path_mover.gd), so cow and car never wait on each other.
## Reaching the fountain's outer step fires `reached_event` (data on the
## node) and the cow stays. No marker, no count: the only guide is the hum.
##
## Where the lanes are is not written here: a lane is the strip either side
## of a vehicle's loop (the `vehicle` group), so the roads the cows respect
## are exactly the roads the traffic drives.
class_name Cow
extends CharacterBody3D

## A hum reached it and it set off toward where the player stood.
signal called(target: Vector3)
## It stands on the fountain's outer step: its event has fired.
signal reached_fountain

enum Mode { GRAZING, CALLED }

const GROUP := "cow"
const VEHICLE_GROUP := "vehicle"
const PLAYER_GROUP := "player"
## How far one hum walks a cow.
const CALL_REACH := 8.0
const CALL_SPEED := 1.0
const GRAZE_SPEED := 0.5
## A cow grazes within this of its home spot.
const GRAZE_RADIUS := 3.0
const GRAZE_WAIT_MIN := 2.0
const GRAZE_WAIT_MAX := 6.0
const GRAZE_TRIES := 4
## It does not step into a lane while any vehicle is within this.
const VEHICLE_CLEARANCE := 6.0
## A lane reaches this far either side of a vehicle's path line.
const LANE_HALF_WIDTH := 4.0
## How far ahead of its centre a cow looks before stepping off the kerb.
const LOOK_AHEAD := 1.0
## Leaving the road: the walk is extended by this much at a time.
const CLEAR_STEP := 1.0
const ARRIVE_DISTANCE := 0.4
const ACCELERATION := 4.0
const TURN_SPEED := 4.0
const GRAVITY := 18.0
## The kerb (0.16 m) and the fountain's step, as for the player.
const STEP_HEIGHT := 0.36
## A called cow that cannot get on (a wall, a parked car) gives up after this.
const STUCK_SECONDS := 2.0
const STUCK_DISTANCE := 0.05

## The event this cow fires on reaching the fountain's step (GDD §7: data).
@export var reached_event := "cow_reached_fountain_0"
@export var fountain_position := Vector3.ZERO
## Within this of the fountain counts as its outer step.
@export_range(1.0, 20.0, 0.5) var fountain_reach := 9.0
## Where this cow stands when a loaded journey already has it at the
## fountain: a cow's position is not saved, its event is.
@export var rest_position := Vector3.ZERO

var _mode := Mode.GRAZING
var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _has_graze_target := false
var _graze_wait := 0.0
var _heading := Vector3.FORWARD
var _waiting := false
var _at_fountain := false
var _stuck_for := 0.0
var _last_position := Vector3.ZERO


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(Interactable.SOUND_SOURCE_GROUP)
	if GameState.has_event(reached_event):
		global_position = rest_position
		_at_fountain = true
	_home = global_position
	_last_position = global_position
	_graze_wait = randf_range(GRAZE_WAIT_MIN, GRAZE_WAIT_MAX)


func _physics_process(delta: float) -> void:
	match _mode:
		Mode.GRAZING:
			_graze(delta)
		Mode.CALLED:
			_answer_call(delta)
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	_step_up(delta)
	move_and_slide()
	if not _at_fountain and _flat_distance(global_position, fountain_position) <= fountain_reach:
		_reach_fountain()


## The player's hum reaches it: it walks toward where they stood, up to
## CALL_REACH. A cow that has reached the fountain has arrived and stays.
func hear_hum() -> bool:
	if _at_fountain:
		return false
	var players := get_tree().get_nodes_in_group(PLAYER_GROUP)
	if players.is_empty():
		return false
	var toward: Vector3 = (players[0] as Node3D).global_position - global_position
	toward.y = 0.0
	if toward.length() > CALL_REACH:
		toward = toward.normalized() * CALL_REACH
	_target = global_position + toward
	_mode = Mode.CALLED
	_has_graze_target = false
	_stuck_for = 0.0
	_last_position = global_position
	called.emit(_target)
	return true


func is_called() -> bool:
	return _mode == Mode.CALLED


## Standing at a kerb because a vehicle is near the lane ahead.
func is_waiting() -> bool:
	return _waiting


func is_at_fountain() -> bool:
	return _at_fountain


func call_target() -> Vector3:
	return _target


func home() -> Vector3:
	return _home


# -- behaviour ----------------------------------------------------------------


func _graze(delta: float) -> void:
	if _has_graze_target:
		if _walk(delta, _target, GRAZE_SPEED):
			_has_graze_target = false
			_graze_wait = randf_range(GRAZE_WAIT_MIN, GRAZE_WAIT_MAX)
		return
	_stand(delta)
	_graze_wait -= delta
	if _graze_wait > 0.0:
		return
	_graze_wait = randf_range(GRAZE_WAIT_MIN, GRAZE_WAIT_MAX)
	for _try in GRAZE_TRIES:
		var angle := randf_range(0.0, TAU)
		var reach := randf_range(GRAZE_RADIUS * 0.3, GRAZE_RADIUS)
		var spot := _home + Vector3(cos(angle), 0.0, sin(angle)) * reach
		# A grazing cow does not drift into the road on its own.
		if not _in_lane(spot):
			_target = spot
			_has_graze_target = true
			return


func _answer_call(delta: float) -> void:
	if _walk(delta, _target, CALL_SPEED):
		if _in_lane(global_position):
			# Never settle in the road: one more step the same way.
			_target = global_position + _heading * CLEAR_STEP
			return
		_settle()
		return
	if _waiting:
		_stuck_for = 0.0
	elif global_position.distance_to(_last_position) < STUCK_DISTANCE:
		_stuck_for += delta
		if _stuck_for >= STUCK_SECONDS:
			_settle()
	else:
		_stuck_for = 0.0
	_last_position = global_position


func _settle() -> void:
	_mode = Mode.GRAZING
	_home = global_position
	_has_graze_target = false
	_waiting = false
	_graze_wait = randf_range(GRAZE_WAIT_MIN, GRAZE_WAIT_MAX)


func _reach_fountain() -> void:
	_at_fountain = true
	_settle()
	GameState.fire_event(reached_event)
	reached_fountain.emit()


## One step toward a point on the ground. Returns true on arrival. Stops
## at a kerb while a vehicle is near the lane just ahead.
func _walk(delta: float, target: Vector3, speed: float) -> bool:
	var to_target := target - global_position
	to_target.y = 0.0
	if to_target.length() <= ARRIVE_DISTANCE:
		_waiting = false
		_stand(delta)
		return true
	var direction := to_target.normalized()
	var ahead := global_position + direction * LOOK_AHEAD
	_waiting = not _in_lane(global_position) and _in_lane(ahead) and _vehicle_near()
	if _waiting:
		_stand(delta)
		return false
	_heading = direction
	velocity.x = move_toward(velocity.x, direction.x * speed, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, ACCELERATION * delta)
	# -Z is forward, as for the player and the path movers.
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), TURN_SPEED * delta)
	return false


func _stand(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, 0.0, ACCELERATION * delta)


## Lifts the body over a low ledge in its path (the player's three sweeps).
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


# -- the traffic --------------------------------------------------------------


## Any vehicle within VEHICLE_CLEARANCE, on the ground plane.
func _vehicle_near() -> bool:
	for node in get_tree().get_nodes_in_group(VEHICLE_GROUP):
		var vehicle := node as Node3D
		if vehicle == null:
			continue
		if _flat_distance(vehicle.global_position, global_position) <= VEHICLE_CLEARANCE:
			return true
	return false


## Is the point within LANE_HALF_WIDTH of any vehicle's loop?
func _in_lane(point: Vector3) -> bool:
	var flat := Vector2(point.x, point.z)
	for node in get_tree().get_nodes_in_group(VEHICLE_GROUP):
		var points: Variant = node.get("points")
		if not points is PackedVector3Array or points.size() < 2:
			continue
		for i in points.size():
			var from: Vector3 = points[i]
			var to: Vector3 = points[(i + 1) % points.size()]
			var nearest := Geometry2D.get_closest_point_to_segment(
				flat, Vector2(from.x, from.z), Vector2(to.x, to.z)
			)
			if nearest.distance_to(flat) <= LANE_HALF_WIDTH:
				return true
	return false


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
