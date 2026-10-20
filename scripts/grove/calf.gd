## The calf of the Grove: it wanders its meadow, comes when the player hums,
## and once petted follows them about.
##
## GDD §3 Act 1 "Waking" ("A calf nudges them"), §3a Act 1 ("Hold the
## button: the character hums. The calf and birds come"), §6 "Call" ("In the
## Grove the calf and birds respond") and §7 micro-interactions ("Pet the
## calf in the Grove: it follows you"). It is in the `sound_source` group so
## the Place's hum reaches it through `hear_hum()`, like Tulu. Petting sets
## one flag, `pet_flag`, and nothing counts it or rewards it; a loaded
## journey with the flag set finds the calf already following.
##
## The *Pet* area sits under `Reach`, not directly under this node, so the
## Place's *Listen* subtitle (for an Interactable whose parent is a sound
## source) does not fire for a pat on a calf.
extends Node3D

signal came
signal petted

enum Mode { WANDERING, COMING, FOLLOWING }

const WALK_SPEED := 1.3
const TURN_SPEED := 5.0
## How close it comes to the player when called, and how far behind it
## walks once it follows.
const COME_DISTANCE := 1.6
const FOLLOW_DISTANCE := 2.0
## Seconds a hum keeps its attention before it wanders off again.
const INTEREST_SECONDS := 14.0
const PAUSE_MIN := 1.5
const PAUSE_MAX := 4.5
const NUZZLE_TILT := 0.35
const NUZZLE_SECONDS := 0.6

## The flag petting sets (GDD §7: "it follows you until the Veil").
@export var pet_flag := "pet_calf"
## How far from where it started the wandering roams.
@export_range(1.0, 30.0, 0.5) var wander_radius := 8.0

var _mode := Mode.WANDERING
var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _pause := 0.0
var _interest := 0.0
var _rng := RandomNumberGenerator.new()
var _nuzzle: Tween = null

@onready var _pet: Interactable = %Pet
@onready var _head: Node3D = %Head


func _ready() -> void:
	add_to_group(Interactable.SOUND_SOURCE_GROUP)
	_home = global_position
	_target = _home
	_rng.randomize()
	_pet.used.connect(_on_pet)
	if GameState.has_flag(pet_flag):
		_mode = Mode.FOLLOWING
	GameState.flag_changed.connect(_on_flag_changed)


func _physics_process(delta: float) -> void:
	var player := _find_player()
	match _mode:
		Mode.WANDERING:
			_wander(delta)
		Mode.COMING:
			_interest -= delta
			if player == null or _interest <= 0.0:
				_mode = Mode.WANDERING
				_pause = PAUSE_MAX
			else:
				_approach(player, COME_DISTANCE, delta)
		Mode.FOLLOWING:
			if player != null:
				_approach(player, FOLLOW_DISTANCE, delta)


func mode() -> Mode:
	return _mode


## The player's hum reaches it (Place.hum): it comes, unless it is already
## at their heels.
func hear_hum() -> bool:
	if _mode == Mode.FOLLOWING:
		return false
	_mode = Mode.COMING
	_interest = INTEREST_SECONDS
	came.emit()
	return true


func is_nuzzling() -> bool:
	return _nuzzle != null and _nuzzle.is_running()


func _on_pet(_player: Node3D) -> void:
	GameState.set_flag(pet_flag)
	_mode = Mode.FOLLOWING
	_animate_nuzzle()
	petted.emit()


func _on_flag_changed(flag: String, is_set: bool) -> void:
	if flag == pet_flag and is_set:
		_mode = Mode.FOLLOWING


func _wander(delta: float) -> void:
	if _pause > 0.0:
		_pause -= delta
		return
	if _step_toward(_target, delta) < 0.3:
		_pause = _rng.randf_range(PAUSE_MIN, PAUSE_MAX)
		var angle := _rng.randf_range(0.0, TAU)
		var reach := _rng.randf_range(0.0, wander_radius)
		_target = _home + Vector3(sin(angle) * reach, 0.0, cos(angle) * reach)


func _approach(player: Node3D, keep: float, delta: float) -> void:
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() > keep + 0.5:
		_step_toward(player.global_position - to_player.normalized() * keep, delta)
	else:
		_face(player.global_position, delta)


## Walks toward [param target] on the flat; returns the remaining distance.
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
	to.y = 0.0
	if to.length() < 0.05:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), TURN_SPEED * delta)


## The head dips and comes back up: a nudge.
func _animate_nuzzle() -> void:
	if _nuzzle != null:
		_nuzzle.kill()
	_nuzzle = create_tween()
	_nuzzle.tween_property(_head, "rotation:x", NUZZLE_TILT, NUZZLE_SECONDS * 0.5)
	_nuzzle.tween_property(_head, "rotation:x", 0.0, NUZZLE_SECONDS * 0.5)


func _find_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if not players.is_empty() else null
