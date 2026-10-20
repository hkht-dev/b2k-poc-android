## Something in a room the player can *Look* at: a photograph, a lock, a
## camera.
##
## GDD §6 "Interaction": *Look* is one of the five verbs. GDD §7
## "Micro-interactions": a look answers with a one-line thought, no giver, no
## reward. The look opens one dialogue line; which line, and so which flags
## the look leaves behind (the line's own `sets`, data/dialogue/en.json), is
## data on the node, set by the generators, never a literal in code.
extends Node3D

signal looked(line_id: String)

## The dialogue line *Look* opens (data/dialogue/en.json).
@export var line_id := ""
## The box in front of the thing, in metres, in which the verb is offered.
@export var reach := Vector3(1.6, 2.2, 1.4)

@onready var _look: Interactable = %Look
@onready var _shape: CollisionShape3D = %Shape


func _ready() -> void:
	var box := BoxShape3D.new()
	box.size = reach
	_shape.shape = box
	_shape.position = Vector3(0.0, reach.y * 0.5, 0.0)
	_look.used.connect(_on_look)


func look_area() -> Interactable:
	return _look


func _on_look(_player: Node3D) -> void:
	if Content.dialogue.start(line_id):
		looked.emit(line_id)
