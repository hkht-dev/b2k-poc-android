## Tulu, the boy humming three notes at the fountain's edge.
##
## GDD §3 Act 3 "Arrival", §4 "Tulu: the thread", §5 "the shrine room is
## tucked behind the chai stall, found by following Tulu", and
## CLAUDE_CODE_BRIEF.md §4.3. He hums on a loop, positional and faint beyond
## ~15 m. *Listen* plays the notes clearly, drifts the camera to him and sets
## `heard_tulu`; then he walks slowly toward the chai stall's back door,
## pausing when the player falls behind. If ignored, he follows the player at
## a distance. After `heard_tulu`, the player's hum is answered with his
## notes from wherever he is (GDD §6 "Call").
##
## At the door he turns to the player, hums once more, and a subtitle says
## what he does; `at_door_flag` is set. From then on the button beside him
## says *Talk* (his line is data, `entry_lines`), and a hum within
## DOOR_HUM_REACH also stirs the chant in the room behind the door (GDD §7
## "Hum near the shrine: Madhuri's chant rises to meet the note").
##
## No marker, no arrow, no objective text: the only guide is sound.
extends Node3D

signal listened
signal replied
signal arrived_at_door
signal talked(line_id: String)

enum Mode { WAITING, LEADING, FOLLOWING }

const FLAG_HEARD := "heard_tulu"
const WALK_SPEED := 1.1
## He waits when the player is further behind than this (§4.3).
const LEAD_PAUSE_DISTANCE := 8.0
## When ignored, he keeps about this far from the player.
const FOLLOW_DISTANCE := 5.0
const FOLLOW_AFTER := 20.0
const TURN_SPEED := 6.0
## One answer at a time: his notes are 4 s long.
const REPLY_SECONDS := 4.0
## A hum this close to him at the door reaches the room behind it too.
const DOOR_HUM_REACH := 10.0
## How long the arrival subtitle stays.
const POINTS_SECONDS := 4.0
## The Glimpse: he looks up and smiles (GDD §6) — a tilt back for a moment.
const LOOK_UP_TILT := 0.22
const LOOK_UP_SECONDS := 2.5

@export var waypoints: PackedVector3Array = PackedVector3Array()
## Set when he reaches his last waypoint. The Talk verb on him requires it.
@export var at_door_flag := "tulu_at_door"
## Shown once per journey, when he arrives at the door.
@export var points_subtitle_id := "sub.tulu_points"
## Dialogue line ids *Talk* tries in order; the first whose `requires` hold opens.
@export var entry_lines: PackedStringArray = PackedStringArray()
## The group of the AudioStreamPlayer3D at the back door that a hum stirs.
@export var chant_group := "chant_outside"

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
@onready var _talk: Interactable = %Talk
@onready var _figure: Node3D = $Figure


func _ready() -> void:
	add_to_group(Interactable.SOUND_SOURCE_GROUP)
	_listen.used.connect(_on_listen)
	_talk.used.connect(_on_talk)
	_hum.play()
	if GameState.has_flag(FLAG_HEARD):
		_mode = Mode.LEADING
	if GameState.has_flag(at_door_flag) and not waypoints.is_empty():
		# A loaded journey finds him where he was: at the door, not walking
		# the route from the fountain again.
		_mode = Mode.LEADING
		_waypoint = waypoints.size()
		global_position = waypoints[waypoints.size() - 1]
	GameState.flag_changed.connect(_on_flag_changed)


func _physics_process(delta: float) -> void:
	_player = _find_player()
	_reply_timer = maxf(0.0, _reply_timer - delta)
	# At the door the button beside him says Talk, not Listen: both areas sit
	# on him, and the place offers the nearer, so only one may be open.
	_listen.enabled = not is_at_the_door()
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
## heard the first time (GDD §6 "Call": "after beat 12, Tulu answers"). At
## the door, a hum close to him reaches the room behind it as well.
func hear_hum() -> bool:
	if not GameState.has_flag(FLAG_HEARD):
		return false
	if is_at_the_door() and _player_within(DOOR_HUM_REACH):
		_stir_chant()
	if _reply_timer > 0.0:
		return false
	_reply.play()
	_reply_timer = REPLY_SECONDS
	replied.emit()
	return true


func _on_listen(_player_node: Node3D) -> void:
	_reply.play()
	GameState.set_flag(FLAG_HEARD)
	_mode = Mode.LEADING
	listened.emit()


func _on_talk(_player_node: Node3D) -> void:
	for line_id in entry_lines:
		if Content.dialogue.start(line_id):
			talked.emit(line_id)
			return


func _on_flag_changed(flag: String, is_set: bool) -> void:
	if flag == FLAG_HEARD and is_set and _mode != Mode.LEADING:
		_mode = Mode.LEADING


func _lead(delta: float) -> void:
	if _waypoint >= waypoints.size():
		if _player != null:
			_face(_player.global_position, delta)
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
		if _waypoint >= waypoints.size():
			_arrive()


## The last waypoint, the back door: he hums once more and turns to the
## player (every frame from now on, in _lead). The flag is set once per
## journey and the subtitle shows with it, not again.
func _arrive() -> void:
	_reply.play()
	_reply_timer = REPLY_SECONDS
	if GameState.set_flag(at_door_flag):
		_show_subtitle(points_subtitle_id)
	arrived_at_door.emit()


## The room behind the door answers too: the chant the street placed at the
## back door (group `chant_group`) plays, if it is not already.
func _stir_chant() -> void:
	for node in get_tree().get_nodes_in_group(chant_group):
		var chant := node as AudioStreamPlayer3D
		if chant != null and not chant.playing:
			chant.play()


## The HUD is the place's he stands in (the scene that instanced him owns
## it); its subtitle line is where a sound is written down (GDD §11).
func _show_subtitle(text_id: String) -> void:
	if owner == null:
		return
	var hud: Node = owner.get_node_or_null("%TouchControls")
	if hud != null and hud.has_method("subtitle"):
		hud.subtitle(text_id, POINTS_SECONDS)


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


func _player_within(distance: float) -> bool:
	var player := _find_player()
	return player != null and global_position.distance_to(player.global_position) <= distance


func _find_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if not players.is_empty() else null
