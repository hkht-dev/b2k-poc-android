## The Counting Man: a man at the bus stop who cannot stop counting coins.
##
## GDD §7 "The Counting Man": he has lost count and will not board a bus
## until he knows the total. *Talk* opens his line; its cards are data in
## data/dialogue (one sets `count_flag`, on which this node opens the count
## screen; one sets the coin flag the quest ends on), and *Sit* beside him
## frees him after a short while, when he laughs. data/quests/counting_man.json
## watches what each option leaves behind and sets `freed_flag`; this node
## only answers that: he stands, walks off down the street along `walk_points`
## and, once, hums one note of the Song. "This quest exists to show that the
## Song can reach anyone." No count is ever shown as a number.
extends Node3D

signal talked(line_id: String)
signal laughed
signal freed
signal note_hummed
signal walked_off

const COUNT_SCREEN := preload("res://scenes/ui/CountScreen.tscn")
const PLAYER_RIG := "Mesh"
const HUD_LAYER := "UI"
const HUD_CONTROLS := "%TouchControls"
const TURN_SPEED := 6.0
const ARRIVE := 0.3

## Dialogue line ids to try in order; the first whose `requires` hold opens.
@export var entry_lines: PackedStringArray = PackedStringArray()
## Set by the "count with him" card. This node opens the count screen on it
## and clears it again when the screen closes, finished or not.
@export var count_flag := "counting_man_counting"
## Fired when the last coin is tapped; the quest's counted branch waits on it.
@export var counted_event := "counting_man_counted"
## Fired when he laughs after the player sat with him.
@export var laughed_event := "counting_man_laughed"
## Set by the quest once any option has freed him.
@export var freed_flag := "counting_man_freed"
@export var laugh_subtitle_id := "sub.counting_man_laugh"
@export var note_subtitle_id := "sub.counting_man_note"
## The clip he and the player sit in (the Glimpse and the bus stop use it too).
@export var sit_pose := "Sitting_Idle"
## How long the player sits with him before he laughs. Not shown anywhere.
@export_range(0.0, 30.0, 0.1) var sit_seconds := 3.0
@export_range(0.2, 40.0, 0.1) var walk_speed := 1.2
## Where he goes when freed, in the scene's space; data set where he is placed.
@export var walk_points: PackedVector3Array = PackedVector3Array()
## He hums his one note on reaching this point of the walk.
@export var note_at_point := 1
## The clips keep the hips at standing height, so the seated figure hangs
## this far below the node to put them on the bench.
@export var seated_drop := -0.46
## The coins beside him, hidden once he has picked them up and gone.
@export var coins_path: NodePath

var _freed := false
var _walking := false
var _gone := false
var _point := 0
var _sit_left := 0.0
var _sitting_with: Node3D = null
var _screen: Control = null
var _own_layer: CanvasLayer = null
var _note_played := false

@onready var _talk: Interactable = %Talk
@onready var _sit: Interactable = %Sit
@onready var _figure: CharacterRig = %Figure
@onready var _note: AudioStreamPlayer3D = %Note


func _ready() -> void:
	_talk.used.connect(_on_talk)
	_sit.used.connect(_on_sit)
	GameState.flag_changed.connect(_on_flag_changed)
	if GameState.has_flag(freed_flag):
		# A loaded journey where he already left: he is simply not here.
		_freed = true
		_leave()
		return
	# A count interrupted by quitting is not resumed; the card starts it again.
	GameState.clear_flag(count_flag)
	_figure.position.y = seated_drop
	_figure.hold_pose(sit_pose)


func _physics_process(delta: float) -> void:
	if _gone:
		return
	if _sit_left > 0.0:
		_sit_left -= delta
		if _sit_left <= 0.0:
			_laugh()
	if _freed and not _walking and _may_stand():
		_stand_up()
	if _walking:
		_walk(delta)
	var usable := not _freed and _sit_left <= 0.0
	_talk.enabled = usable
	_sit.enabled = usable


func is_freed() -> bool:
	return _freed


func is_walking() -> bool:
	return _walking


func has_gone() -> bool:
	return _gone


func note_played() -> bool:
	return _note_played


func is_sitting_with_player() -> bool:
	return _sit_left > 0.0


func count_screen() -> Control:
	return _screen


func figure() -> CharacterRig:
	return _figure


func _on_talk(_player: Node3D) -> void:
	for line_id in entry_lines:
		if Content.dialogue.start(line_id):
			talked.emit(line_id)
			return


## *Sit*: the player sits beside him and, a little later, he laughs.
func _on_sit(player: Node3D) -> void:
	if _freed or _sit_left > 0.0:
		return
	_sit_left = maxf(sit_seconds, 0.001)
	_sitting_with = player
	var rig := player.get_node_or_null(PLAYER_RIG)
	if rig != null and rig.has_method("hold_pose"):
		rig.hold_pose(sit_pose)


func _laugh() -> void:
	_sit_left = 0.0
	_release_player()
	_subtitle(laugh_subtitle_id)
	laughed.emit()
	GameState.fire_event(laughed_event)


func _release_player() -> void:
	if _sitting_with == null:
		return
	var rig := _sitting_with.get_node_or_null(PLAYER_RIG)
	if rig != null and rig.has_method("release_pose"):
		rig.release_pose()
	_sitting_with = null


func _on_flag_changed(flag: String, is_set: bool) -> void:
	if not is_set or _freed:
		return
	if flag == count_flag:
		_open_count_screen()
	elif flag == freed_flag:
		_freed = true
		freed.emit()


func _open_count_screen() -> void:
	if _screen != null:
		return
	_screen = COUNT_SCREEN.instantiate()
	_screen.finished.connect(_on_count_finished)
	_screen.closed.connect(_on_count_closed)
	_hud_layer().add_child(_screen)


func _on_count_finished() -> void:
	GameState.fire_event(counted_event)


func _on_count_closed() -> void:
	if _screen != null:
		_screen.get_parent().remove_child(_screen)
		_screen.queue_free()
		_screen = null
	GameState.clear_flag(count_flag)


## He gets up only once the screen or his line is out of the way, so the
## player sees him go.
func _may_stand() -> bool:
	return _screen == null and _sit_left <= 0.0 and not Content.dialogue.is_running()


func _stand_up() -> void:
	_walking = true
	_point = 0
	_figure.position.y = 0.0
	_figure.release_pose()
	_set_coins_visible(false)


func _walk(delta: float) -> void:
	if _point >= walk_points.size():
		_leave()
		return
	if _step_toward(walk_points[_point], delta) < ARRIVE:
		if _point == note_at_point:
			_hum_note()
		_point += 1


## One note of the Song, once, from wherever he has got to.
func _hum_note() -> void:
	if _note_played:
		return
	_note_played = true
	_note.play()
	_subtitle(note_subtitle_id)
	note_hummed.emit()


## Off the end of his route, or never here at all (a loaded journey): gone.
## A walk too short to reach `note_at_point` still gets its note.
func _leave() -> void:
	if _walking and not _note_played:
		_hum_note()
	_walking = false
	_gone = true
	visible = false
	_talk.enabled = false
	_sit.enabled = false
	_set_coins_visible(false)
	walked_off.emit()


func _set_coins_visible(on: bool) -> void:
	if coins_path.is_empty():
		return
	var coins := get_node_or_null(coins_path) as Node3D
	if coins != null:
		coins.visible = on


func _step_toward(target: Vector3, delta: float) -> float:
	var to := target - global_position
	to.y = 0.0
	var distance := to.length()
	if distance > 0.05:
		global_position += to.normalized() * minf(walk_speed * delta, distance)
		_face(target, delta)
	return distance


func _face(point: Vector3, delta: float) -> void:
	var to := point - global_position
	if to.length() < 0.05:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), TURN_SPEED * delta)


## The place's HUD layer, where the choice cards also live, so the pause menu
## still draws above the count screen. Alone in a test, a layer of his own.
func _hud_layer() -> Node:
	var node := get_parent()
	while node != null:
		var layer := node.get_node_or_null(HUD_LAYER)
		if layer is CanvasLayer:
			return layer
		node = node.get_parent()
	if _own_layer == null:
		_own_layer = CanvasLayer.new()
		add_child(_own_layer)
	return _own_layer


## A subtitle through the place's controls (GDD §11: every vocal sound).
func _subtitle(text_id: String) -> void:
	var node := get_parent()
	while node != null:
		if node is Place:
			var hud := node.get_node_or_null(HUD_CONTROLS)
			if hud != null and hud.has_method("subtitle"):
				hud.subtitle(text_id)
			return
		node = node.get_parent()
