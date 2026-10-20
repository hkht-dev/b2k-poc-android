## A Glimpse: Krishna's silhouette, far, backlit, gone when you arrive.
##
## GDD §6 "Glimpses", CLAUDE_CODE_BRIEF.md §4.5. This one sits on the
## traffic-light beam. It appears the first time `trigger_flag` is set
## (`gave_dry_fountain`; never on a timer, never on `took_`), stays for
## `seconds`, and ends early when the player comes within `end_distance`:
## the silhouette fades over half a second and a single peacock feather
## lies on the pavement beneath. Pedestrians do not react; Tulu, if he is in
## the scene, looks up. *Your journey* records exactly one line. Nothing
## counts it, rewards it or requires it.
extends Node3D

signal appeared
signal ended

const SILHOUETTE := preload("res://assets/materials/silhouette.tres")
const FLUTE := preload("res://scenes/quest/Flute.tscn")
const FADE_SECONDS := 0.5
const LOOK_UP_GROUP := "sound_source"

@export var trigger_flag := "gave_dry_fountain"
## Set once the Glimpse has happened, so it never happens twice.
@export var seen_flag := "glimpsed_traffic_light"
@export var journey_line_id := "journey.glimpse.traffic_light"
@export_range(1.0, 12.0, 0.5) var seconds := 5.0
@export_range(1.0, 20.0, 0.5) var end_distance := 6.0

var _active := false
var _left := 0.0
var _material: StandardMaterial3D = null

@onready var _figure: CharacterRig = %Figure
@onready var _light: OmniLight3D = %RimLight
@onready var _feather: Node3D = %FeatherPickup


func _ready() -> void:
	_material = SILHOUETTE.duplicate()
	_figure.paint_all(_material)
	_figure.carry(true, FLUTE)
	_figure.visible = false
	_light.visible = false
	_feather.visible = GameState.has_flag(seen_flag) and not GameState.has_event(_feather.event)
	GameState.flag_changed.connect(_on_flag_changed)


func _physics_process(delta: float) -> void:
	if not _active:
		return
	_left -= delta
	var player := _find_player()
	var near := (
		player != null and player.global_position.distance_to(global_position) <= end_distance
	)
	if _left <= 0.0 or near:
		_end()


func is_active() -> bool:
	return _active


func _on_flag_changed(flag: String, is_set: bool) -> void:
	if flag == trigger_flag and is_set and not GameState.has_flag(seen_flag) and not _active:
		_appear()
	elif flag == seen_flag and is_set and not _active:
		# Seen (by this scene or a loaded journey): what it left behind lies
		# there until picked up.
		_feather.visible = not GameState.has_event(_feather.event)


func _appear() -> void:
	_active = true
	_left = seconds
	_material.albedo_color.a = 1.0
	_figure.visible = true
	_light.visible = true
	for node in get_tree().get_nodes_in_group(LOOK_UP_GROUP):
		if node.has_method("look_up_at"):
			node.look_up_at(global_position)
	appeared.emit()


func _end() -> void:
	_active = false
	GameState.set_flag(seen_flag)
	GameState.add_journey_line(journey_line_id)
	_feather.visible = true
	_light.visible = false
	var tween := create_tween()
	tween.tween_property(_material, "albedo_color:a", 0.0, FADE_SECONDS)
	tween.tween_callback(func() -> void: _figure.visible = false)
	ended.emit()


func _find_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if not players.is_empty() else null
