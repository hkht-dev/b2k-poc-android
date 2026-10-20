## A Glimpse: Krishna's silhouette, far, backlit, gone when you arrive.
##
## GDD §6 "Glimpses", CLAUDE_CODE_BRIEF.md §4.5. The five fixed points of the
## Street share this scene; everything that differs between them is data on
## the instance: the condition that shows it (`trigger_condition`, in the
## grammar of scripts/lib/condition.gd; tied to the player's state, never a
## timer), the pose, how long it stays, how near is near, what it leaves and
## where. It appears the first time its condition holds: on the flag change
## in the Street, or on arriving in the Street with the condition already
## true, since a flag set inside a shop never reaches a scene that was not
## loaded. It stays for `seconds` and ends early when the player comes within
## `end_distance` across the ground: the silhouette fades over half a second
## and a single peacock feather or a jasmine flower lies where it fell.
## Nobody on the street reacts; Tulu does, once, at the traffic light
## (`witnessed`). *Your journey* records exactly one line. Nothing counts it,
## rewards it or requires it.
extends Node3D

signal appeared
signal ended

const SILHOUETTE := preload("res://assets/materials/silhouette.tres")
const FLUTE := preload("res://scenes/quest/Flute.tscn")
const FADE_SECONDS := 0.5
const LOOK_UP_GROUP := "sound_source"
## What a Glimpse may leave behind (GDD §6), each a pick-up node in the scene.
const LEAVES_FEATHER := "feather"
const LEAVES_JASMINE := "jasmine"

## The flag that shows it, when `trigger_condition` is empty (the P5 form).
@export var trigger_flag := "gave_dry_fountain"
## A condition over flags and events (scripts/lib/condition.gd), such as
## "flag:rukma_heard and not flag:rukma_key_taken". Wins over `trigger_flag`.
@export var trigger_condition := ""
## Set once the Glimpse has happened, so it never happens twice.
@export var seen_flag := "glimpsed_traffic_light"
@export var journey_line_id := "journey.glimpse.traffic_light"
@export_range(1.0, 12.0, 0.5) var seconds := 5.0
## Within this many metres across the ground it ends: a perch high up is
## arrived at from the pavement beneath it.
@export_range(1.0, 40.0, 0.5) var end_distance := 6.0
## "feather" or "jasmine": which pick-up lies there afterwards.
@export var leaves := LEAVES_FEATHER
## Where it lies, in this node's own space. The default is the traffic
## light's pavement, below and in front; zero for a Glimpse at ground level.
@export var leaves_offset := Vector3(0.0, -5.54, -4.2)
## The event the pick-up fires when taken. Empty keeps the pick-up scene's
## own; two points that leave the same thing must not share one.
@export var pickup_event := ""
## The clip the figure holds: sitting on a beam, standing in a doorway.
@export var pose := "Sitting_Idle"
## GDD §6: no one on the street reacts, except Tulu, once, at the traffic
## light. True there and nowhere else.
@export var witnessed := false

var _active := false
var _left := 0.0
var _material: StandardMaterial3D = null
var _pickup: Node3D = null
var _well_formed := true

@onready var _figure: CharacterRig = %Figure
@onready var _light: OmniLight3D = %RimLight
@onready var _feather: Node3D = %FeatherPickup
@onready var _jasmine: Node3D = %JasminePickup


func _ready() -> void:
	_material = SILHOUETTE.duplicate()
	_figure.paint_all(_material)
	_figure.carry(true, FLUTE)
	_figure.visible = false
	_light.visible = false
	if pose != _figure.idle_animation:
		_figure.hold_pose(pose)
	_pickup = _choose_pickup()
	_pickup.position = leaves_offset
	if not pickup_event.is_empty():
		_pickup.event = pickup_event
	_show_what_it_left()
	var expr := _condition()
	_well_formed = not expr.is_empty() and Condition.is_well_formed(expr)
	if not _well_formed:
		push_error("Glimpse %s: cannot read its condition '%s'" % [name, expr])
	GameState.flag_changed.connect(_on_flag_changed)
	GameState.event_fired.connect(_on_event_fired)
	_appear_if_due()


func _physics_process(delta: float) -> void:
	if not _active:
		return
	_left -= delta
	var player := _find_player()
	var near := player != null and _ground_distance(player.global_position) <= end_distance
	if _left <= 0.0 or near:
		_end()


func is_active() -> bool:
	return _active


## The feather or jasmine this point leaves (scripts/quest/pickup_item.gd).
func pickup() -> Node3D:
	return _pickup


## The condition that shows it, as the evaluator reads it.
func condition() -> String:
	return _condition()


func _on_flag_changed(flag: String, _is_set: bool) -> void:
	if flag == seen_flag and not _active:
		# Seen (by this scene or a loaded journey): what it left behind lies
		# there until picked up.
		_show_what_it_left()
	_appear_if_due()


func _on_event_fired(_event: String) -> void:
	_appear_if_due()


func _appear_if_due() -> void:
	if _active or not _well_formed or GameState.has_flag(seen_flag):
		return
	if Condition.evaluate(_condition(), GameState.flags, GameState.events):
		_appear()


func _appear() -> void:
	_active = true
	_left = seconds
	_material.albedo_color.a = 1.0
	_figure.visible = true
	_light.visible = true
	if witnessed:
		for node in get_tree().get_nodes_in_group(LOOK_UP_GROUP):
			if node.has_method("look_up_at"):
				node.look_up_at(global_position)
	appeared.emit()


func _end() -> void:
	_active = false
	GameState.set_flag(seen_flag)
	GameState.add_journey_line(journey_line_id)
	_pickup.visible = true
	_light.visible = false
	var tween := create_tween()
	tween.tween_property(_material, "albedo_color:a", 0.0, FADE_SECONDS)
	tween.tween_callback(func() -> void: _figure.visible = false)
	ended.emit()


func _condition() -> String:
	if not trigger_condition.is_empty():
		return trigger_condition
	return Condition.FLAG_PREFIX + trigger_flag if not trigger_flag.is_empty() else ""


## Keeps the pick-up named by `leaves` and frees the other.
func _choose_pickup() -> Node3D:
	var pickups := {LEAVES_FEATHER: _feather, LEAVES_JASMINE: _jasmine}
	if not pickups.has(leaves):
		push_error("Glimpse %s: leaves '%s' is not one of %s" % [name, leaves, pickups.keys()])
		leaves = LEAVES_FEATHER
	for kind: String in pickups:
		if kind != leaves:
			pickups[kind].queue_free()
	return pickups[leaves]


func _show_what_it_left() -> void:
	_pickup.visible = GameState.has_flag(seen_flag) and not GameState.has_event(_pickup.event)


func _ground_distance(point: Vector3) -> float:
	var here := global_position
	return Vector2(point.x, point.z).distance_to(Vector2(here.x, here.z))


func _find_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if not players.is_empty() else null
