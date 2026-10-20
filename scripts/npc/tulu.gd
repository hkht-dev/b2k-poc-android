## Tulu, the boy humming three notes at the fountain's edge.
##
## GDD §3 Act 3 "Arrival" and CLAUDE_CODE_BRIEF.md §4.3. He hums on a loop,
## positional and faint beyond ~15 m. *Listen* plays the notes clearly, drifts
## the camera to him and sets `heard_tulu`; then he walks slowly toward the
## chai stall's back door, pausing when the player falls behind. If ignored,
## he follows the player at a distance. After `heard_tulu`, the player's hum
## is answered with his notes from wherever he is (GDD §6 "Call").
##
## No marker, no arrow, no objective text: the only guide is sound.
extends Node3D

signal listened
signal replied

enum Mode { WAITING, LEADING, FOLLOWING }

const FLAG_HEARD := "heard_tulu"
const WALK_SPEED := 1.1
## He waits when the player is further behind than this (§4.3).
const LEAD_PAUSE_DISTANCE := 8.0
## When ignored, he keeps about this far from the player.
const FOLLOW_DISTANCE := 5.0
const FOLLOW_AFTER := 20.0
const TURN_SPEED := 6.0
## The Glimpse: he looks up and smiles (GDD §6) — a tilt back for a moment.
const LOOK_UP_TILT := 0.22
const LOOK_UP_SECONDS := 2.5

@export var waypoints: PackedVector3Array = PackedVector3Array()

var _mode := Mode.WAITING
var _waypoint := 0
var _ignored_for := 0.0
var _player: Node3D = null
var _reply_timer := 0.0
var _look_up_left := 0.0
var _look_up_at := Vector3.ZERO

@onready var _hum: AudioStreamPlayer3D = %HumLoop
@onready var _reply: AudioStreamPlayer3D = %Reply
@onready var _listen: Interactable = %Listen
@onready var _figure: Node3D = $Figure


func _ready() -> void:
	add_to_group(Interactable.SOUND_SOURCE_GROUP)
	_listen.used.connect(_on_listen)
	_hum.play()
	if GameState.has_flag(FLAG_HEARD):
		_mode = Mode.LEADING
	GameState.flag_changed.connect(_on_flag_changed)


func _physics_process(delta: float) -> void:
	_player = _find_player()
	_reply_timer = maxf(0.0, _reply_timer - delta)
	if _look_up_left > 0.0:
		_look_up_left -= delta
		_face(_look_up_at, delta)
		_figure.rotation.x = lerpf(_figure.rotation.x, -LOOK_UP_TILT, 4.0 * delta)
		return
	_figure.rotation.x = lerpf(_figure.rotation.x, 0.0, 4.0 * delta)
	match _mode:
		Mode.WAITING:
			_ignored_for += delta
			if _player != null and _ignored_for > FOLLOW_AFTER:
				_mode = Mode.FOLLOWING
		Mode.LEADING:
			_lead(delta)
		Mode.FOLLOWING:
			_follow(delta)


func mode() -> Mode:
	return _mode


func is_at_the_door() -> bool:
	return _mode == Mode.LEADING and _waypoint >= waypoints.size()


## A Glimpse appeared at [param point]: he looks up at it for a moment.
func look_up_at(point: Vector3) -> void:
	_look_up_at = point
	_look_up_left = LOOK_UP_SECONDS


func is_looking_up() -> bool:
	return _look_up_left > 0.0


## The player's hum reaches him: he answers with his notes, once he has been
## heard the first time (GDD §6 "Call": "after beat 12, Tulu answers").
func hear_hum() -> bool:
	if not GameState.has_flag(FLAG_HEARD) or _reply_timer > 0.0:
		return false
	_reply.play()
	_reply_timer = 4.0
	replied.emit()
	return true


func _on_listen(_player_node: Node3D) -> void:
	_reply.play()
	GameState.set_flag(FLAG_HEARD)
	_mode = Mode.LEADING
	listened.emit()


func _on_flag_changed(flag: String, is_set: bool) -> void:
	if flag == FLAG_HEARD and is_set and _mode != Mode.LEADING:
		_mode = Mode.LEADING


func _lead(delta: float) -> void:
	if _waypoint >= waypoints.size():
		return
	if (
		_player != null
		and global_position.distance_to(_player.global_position) > LEAD_PAUSE_DISTANCE
	):
		_face(_player.global_position, delta)
		return
	var target := waypoints[_waypoint]
	if _step_toward(target, delta) < 0.3:
		_waypoint += 1


func _follow(delta: float) -> void:
	if _player == null:
		return
	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() > FOLLOW_DISTANCE + 1.0:
		_step_toward(_player.global_position - to_player.normalized() * FOLLOW_DISTANCE, delta)
	else:
		_face(_player.global_position, delta)


## Walks toward [param target] on the flat; returns the remaining distance.
func _step_toward(target: Vector3, delta: float) -> float:
	var to := target - global_position
	to.y = 0.0
	var distance := to.length()
	if distance > 0.05:
		var step := minf(WALK_SPEED * delta, distance)
		global_position += to.normalized() * step
		_face(target, delta)
	return distance


func _face(point: Vector3, delta: float) -> void:
	var to := point - global_position
	if to.length() < 0.05:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), TURN_SPEED * delta)


func _find_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if not players.is_empty() else null
