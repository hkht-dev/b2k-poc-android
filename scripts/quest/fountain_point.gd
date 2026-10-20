## The dry fountain as a quest giver: *Look* at it, *Place* a can in it.
##
## CLAUDE_CODE_BRIEF.md §4.4: *Look* opens the fountain's one line ("It's dry.
## The shop beside it is full of water."), which sets `looked_dry_fountain`
## through the dialogue data. *Place* is offered only while the player is
## carrying a can and Gopal has agreed to walk it (the `requires` on the
## Interactable, data on the scene); it fires `can_placed_at_fountain`, the
## quest sets `gave_dry_fountain`, and the basin fills (`WaterPlane`, GDD §7
## "first watering"). A can taken without him can never be placed here: the
## fountain stays dry on that path, as the brief says.
extends Node3D

signal looked
signal placed

const EVENT_PLACED := "can_placed_at_fountain"
const LOOK_LINE := "fountain_look"
const FLAG_GAVE := "gave_dry_fountain"
## Water rises from the basin floor to this height above it, in seconds.
const FILL_HEIGHT := 0.32
const FILL_SECONDS := 6.0

@export var water_loop: AudioStream

var _fill := 0.0
var _tween: Tween = null

@onready var _look: Interactable = %Look
@onready var _place: Interactable = %Place
@onready var _water: MeshInstance3D = %WaterPlane
@onready var _water_audio: AudioStreamPlayer3D = %WaterLoop


func _ready() -> void:
	_look.used.connect(_on_look)
	_place.used.connect(_on_place)
	_water.visible = false
	if water_loop != null:
		_water_audio.stream = water_loop
	if GameState.has_flag(FLAG_GAVE):
		_set_fill(1.0)
	GameState.flag_changed.connect(_on_flag_changed)


func _physics_process(_delta: float) -> void:
	var player := _find_player()
	_place.enabled = player != null and player.is_carrying("can")
	_look.enabled = player != null and not player.is_carrying()


## 0 (dry) to 1 (full).
func fill() -> float:
	return _fill


func is_full() -> bool:
	return _fill >= 0.999


func _on_look(_player: Node3D) -> void:
	Content.dialogue.start(LOOK_LINE)
	looked.emit()


func _on_place(player: Node3D) -> void:
	if not player.is_carrying("can"):
		return
	player.put_down()
	GameState.fire_event(EVENT_PLACED)
	placed.emit()


func _on_flag_changed(flag: String, is_set: bool) -> void:
	if flag == FLAG_GAVE and is_set and not is_full():
		_animate_fill()


func _animate_fill() -> void:
	if _tween != null:
		_tween.kill()
	_water_audio.play()
	_tween = create_tween()
	_tween.tween_method(_set_fill, _fill, 1.0, FILL_SECONDS)


func _set_fill(value: float) -> void:
	_fill = clampf(value, 0.0, 1.0)
	_water.visible = _fill > 0.0
	_water.position.y = _fill * FILL_HEIGHT
	if _fill >= 0.999 and not _water_audio.playing:
		_water_audio.play()


func _find_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if not players.is_empty() else null
