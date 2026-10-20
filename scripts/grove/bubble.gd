## A bubble drifting through the Grove with a tiny world turning inside.
##
## GDD §3 Act 1 "Waking": "Bubbles drift past; a *Look* at one shows a tiny
## world turning inside." §3a: "Tap a drifting bubble: Look — curiosity about
## the material worlds, planted gently." The drift is a slow closed curve
## about where the generator put it, so a bubble never leaves its corner of
## the Grove and the player can always catch one up. *Look* opens the one
## line named on the node; the line, and the flag it leaves, are data in
## data/dialogue/en.json.
extends Node3D

signal looked

## The dialogue line *Look* opens.
@export var line_id := "bubble_look"
## Half-widths of the drift, in metres, east-west, up-down and north-south.
@export var drift := Vector3(3.0, 0.5, 2.5)
## Seconds for one slow turn of the drift.
@export_range(5.0, 120.0, 0.5) var period := 26.0
## Where on its turn this bubble starts, so six do not move as one.
@export_range(0.0, 6.2832, 0.01) var phase := 0.0
## Radians per second the world inside turns.
@export var world_spin := 0.35

var _origin := Vector3.ZERO
var _time := 0.0

@onready var _look: Interactable = %Look
@onready var _world: Node3D = %World


func _ready() -> void:
	_origin = position
	_time = phase * period / TAU
	_look.used.connect(_on_look)
	_place()


func _process(delta: float) -> void:
	_time += delta
	_place()
	_world.rotate_y(world_spin * delta)


func origin() -> Vector3:
	return _origin


func _place() -> void:
	var a := TAU * _time / period
	position = _origin + Vector3(sin(a) * drift.x, sin(a * 1.7) * drift.y, cos(a * 0.8) * drift.z)


func _on_look(_player: Node3D) -> void:
	Content.dialogue.start(line_id)
	looked.emit()
