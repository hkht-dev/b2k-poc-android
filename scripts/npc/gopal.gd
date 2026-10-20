## Gopal Seth, the shopkeeper who carried every can inside.
##
## CLAUDE_CODE_BRIEF.md §4.4, GDD §7 "The Dry Fountain". *Talk* opens the
## first of his lines whose requirements the flags meet — the order is data
## on the scene (`entry_lines`), the requirements live in the dialogue file.
## Once he has agreed to walk one can (`gopal_will_carry`) and the player
## picks one up, he follows them to the fountain with his own can and goes
## back behind the counter when the player has placed it. He never judges:
## the hurt line and the after line are just lines, chosen by flags.
extends Node3D

signal talked(line_id: String)

enum Mode { AT_COUNTER, WALKING_WITH, RETURNING }

const FLAG_WILL_CARRY := "gopal_will_carry"
const FLAG_GAVE := "gave_dry_fountain"
const EVENT_TAKEN := "can_taken_from_shop"
const WALK_SPEED := 1.4
const FOLLOW_DISTANCE := 2.2
const TURN_SPEED := 6.0
const HOME_REACHED := 0.3

## Dialogue line ids to try in order; the first whose `requires` hold opens.
@export var entry_lines: PackedStringArray = PackedStringArray()

var _mode := Mode.AT_COUNTER
var _home := Vector3.ZERO
var _home_yaw := 0.0

@onready var _talk: Interactable = %Talk
@onready var _figure: CharacterRig = %Figure


func _ready() -> void:
	_home = global_position
	_home_yaw = rotation.y
	_talk.used.connect(_on_talk)
	GameState.event_fired.connect(_on_event)
	GameState.flag_changed.connect(_on_flag_changed)
	if GameState.has_flag(FLAG_WILL_CARRY) and not GameState.has_flag(FLAG_GAVE):
		var player := _find_player()
		if player != null and player.is_carrying():
			_mode = Mode.WALKING_WITH
	_figure.carry(_mode == Mode.WALKING_WITH)


func _physics_process(delta: float) -> void:
	var player := _find_player()
	match _mode:
		Mode.WALKING_WITH:
			if player != null:
				_follow(player, delta)
		Mode.RETURNING:
			if _step_toward(_home, delta) < HOME_REACHED:
				_mode = Mode.AT_COUNTER
				rotation.y = _home_yaw
		Mode.AT_COUNTER:
			pass
	_talk.enabled = _mode != Mode.RETURNING


func mode() -> Mode:
	return _mode


func _on_talk(_player: Node3D) -> void:
	for line_id in entry_lines:
		if Content.dialogue.start(line_id):
			talked.emit(line_id)
			return


func _on_event(event: String) -> void:
	if event == EVENT_TAKEN and GameState.has_flag(FLAG_WILL_CARRY):
		_mode = Mode.WALKING_WITH
		_figure.carry(true)


func _on_flag_changed(flag: String, is_set: bool) -> void:
	if flag == FLAG_GAVE and is_set and _mode == Mode.WALKING_WITH:
		_mode = Mode.RETURNING
		_figure.carry(false)


func _follow(player: Node3D, delta: float) -> void:
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() > FOLLOW_DISTANCE + 0.6:
		_step_toward(player.global_position - to_player.normalized() * FOLLOW_DISTANCE, delta)
	else:
		_face(player.global_position, delta)


func _step_toward(target: Vector3, delta: float) -> float:
	var to := target - global_position
	to.y = 0.0
	var distance := to.length()
	if distance > 0.05:
		global_position += to.normalized() * minf(WALK_SPEED * delta, distance)
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
