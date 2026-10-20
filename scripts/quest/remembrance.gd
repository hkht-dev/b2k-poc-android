## Remembrance: the hum held on the fountain steps, and the world's answer.
##
## GDD §3 Act 4 "Remembrance" and §3a Act 4: "Hold the hum while the street
## listens, or sit alone with it. The melody is the Song; a bubble passes;
## the eyes brighten. Remembering; the first pink in the sky." Which dawn the
## player had is a flag the tower sets (`played_for_others` or `kept_veena`,
## GDD §6 "Remembering Krishna"); *Hum here* appears once either is set.
## Using it holds the Place's hum three times over six seconds while the
## player stands still in a pose, and the world answers from `answers`, data
## on the scene: on the full variant the people on the pavements stop and
## turn to the fountain, a bubble drifts over it and the sun warms toward
## rose; on the quiet variant there is no crowd, only the bubble and a softer
## tint. It sets `remembered` and one journey line, and nothing else:
## Madhuri's seed is the shrine's (GDD §3 Act 4 "The service").
extends Node3D

signal remembered

## The group the street's movers are in (scripts/street/path_mover.gd).
const MOVER_GROUP := "path_mover"

## dawn flag -> the world's answer: `crowd` (the people on the pavements stop
## and face here), `tint` (where the sun's colour goes), `journey` (the line
## *Your journey* gets). The first flag set wins.
@export var answers: Dictionary = {}
@export var remembered_flag := "remembered"
## The pose the body holds while humming: a clip in the rig's idle library.
## PLACEHOLDER: the humming idle of GDD §10 "animation sets".
@export var hum_pose := "Idle_Talking"
@export_range(1.0, 20.0, 0.5) var hum_seconds := 6.0
@export_range(1, 6) var hums := 3
@export_range(1.0, 20.0, 0.5) var bubble_seconds := 8.0
@export_range(1.0, 30.0, 0.5) var tint_seconds := 10.0
## The bubble's path, in this node's space: it crosses over the fountain.
@export var bubble_from := Vector3(-9.5, 3.8, -1.5)
@export var bubble_to := Vector3(-4.0, 5.2, -11.0)

var _holding := false

@onready var _hum: Interactable = %HumHere
@onready var _bubble: MeshInstance3D = %Bubble


func _ready() -> void:
	_bubble.visible = false
	_hum.used.connect(_on_hum_here)


func _physics_process(_delta: float) -> void:
	_hum.enabled = (
		not _holding and not GameState.has_flag(remembered_flag) and not dawn_flag().is_empty()
	)


## The dawn the player had: the first flag in `answers` that is set, or "".
func dawn_flag() -> String:
	for flag in answers:
		if GameState.has_flag(str(flag)):
			return str(flag)
	return ""


func is_holding() -> bool:
	return _holding


func bubble() -> MeshInstance3D:
	return _bubble


func _on_hum_here(player: Node3D) -> void:
	var flag := dawn_flag()
	if _holding or flag.is_empty():
		return
	var answer: Dictionary = answers[flag]
	_holding = true
	_hold_still(player, true)
	_answer(answer)
	var gap := hum_seconds / maxi(hums, 1)
	var tween := create_tween()
	for i in hums:
		if i > 0:
			tween.tween_interval(gap)
		tween.tween_callback(_hum_once)
	tween.tween_interval(hum_seconds - gap * (hums - 1))
	tween.tween_callback(_finish.bind(player, str(answer.get("journey", ""))))


## The Call, through the Place, so whatever answers a hum answers this one.
func _hum_once() -> void:
	var place := _find_place()
	if place != null:
		place.hum()


## What the world does, from the data: the crowd, the bubble, the light.
func _answer(answer: Dictionary) -> void:
	if bool(answer.get("crowd", false)):
		for node in get_tree().get_nodes_in_group(MOVER_GROUP):
			if node.has_method("pause_and_face") and _is_person(node):
				node.pause_and_face(global_position, hum_seconds)
	_drift_bubble()
	var place := _find_place()
	if place != null and place.has_method("tint_sun") and answer.has("tint"):
		place.tint_sun(answer["tint"], tint_seconds)


func _drift_bubble() -> void:
	_bubble.position = bubble_from
	_bubble.visible = true
	var tween := create_tween()
	var drift := tween.tween_property(_bubble, "position", bubble_to, bubble_seconds)
	drift.set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void: _bubble.visible = false)


## The body stands still (its physics step is off, so the stick does nothing)
## and holds the pose; or is let go.
func _hold_still(player: Node3D, on: bool) -> void:
	var body := player as CharacterBody3D
	if body != null:
		body.velocity = Vector3.ZERO
	player.set_physics_process(not on)
	var rig: CharacterRig = player.get_node_or_null("%Mesh")
	if rig == null:
		return
	if on:
		rig.hold_pose(hum_pose)
	else:
		rig.release_pose()


func _finish(player: Node3D, journey_line: String) -> void:
	if is_instance_valid(player):
		_hold_still(player, false)
	_holding = false
	GameState.set_flag(remembered_flag)
	GameState.add_journey_line(journey_line)
	remembered.emit()


## A mover with a rigged body on it is a person; the vehicles drive on.
static func _is_person(mover: Node) -> bool:
	for child in mover.get_children():
		if child is CharacterRig:
			return true
	return false


## The Place this sits in: the nearest ancestor that can hum.
func _find_place() -> Node:
	var node := get_parent()
	while node != null:
		if node.has_method("hum"):
			return node
		node = node.get_parent()
	return null
