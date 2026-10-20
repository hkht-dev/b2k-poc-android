## The top of the billboard tower: the roof, the Veena on its stand, and the
## dawn choice.
##
## GDD §5 "Rooftop", §8 Scene E "The dawn choice", §12 (flags only). Walking
## onto the roof sets `arrive_flag` once. *Look* at the stand opens `line_id`
## from the dialogue data, whose two cards set `played_for_others` or
## `kept_veena` themselves; this node only answers the flags: a line in *Your
## journey* for each (data on the scene), and the Veena leaving the stand for
## the player's hands when it is kept. After either, the stand offers
## nothing: the choice is made. Neither card is marked, neither is a score.
extends Node3D

## The player stepped onto the roof for the first time.
signal arrived
## The player looked at the Veena: the choice is on screen.
signal looked

@export var arrive_flag := "on_the_tower"
@export var line_id := "veena_dawn"
## flag -> the line written in *Your journey* when it is set (GDD §6 "Choice").
@export var journey_lines: Dictionary = {}
## Any of these set: the choice was made and the stand offers nothing.
@export var chosen_flags: PackedStringArray = PackedStringArray()
## This flag set: the Veena leaves the stand for the hand, as `take_item`.
@export var take_flag := "kept_veena"
@export var take_item := "veena"

@onready var _arrive: Area3D = %Arrive
@onready var _look: Interactable = %Look
@onready var _veena: Node3D = %VeenaOnStand


func _ready() -> void:
	_arrive.body_entered.connect(_on_body_entered)
	_look.used.connect(_on_look)
	_veena.visible = not GameState.has_flag(take_flag)
	GameState.flag_changed.connect(_on_flag_changed)


func _physics_process(_delta: float) -> void:
	var player := _find_player()
	_look.enabled = not is_chosen() and player != null and not player.is_carrying()


func is_chosen() -> bool:
	for flag in chosen_flags:
		if GameState.has_flag(flag):
			return true
	return false


func veena_on_stand() -> bool:
	return _veena.visible


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and GameState.set_flag(arrive_flag):
		arrived.emit()


func _on_look(_player: Node3D) -> void:
	if Content.dialogue.start(line_id):
		looked.emit()


func _on_flag_changed(flag: String, is_set: bool) -> void:
	if not is_set:
		return
	if journey_lines.has(flag):
		GameState.add_journey_line(str(journey_lines[flag]))
	if flag == take_flag:
		_veena.visible = false
		var player := _find_player()
		if player != null:
			player.carry(take_item)


func _find_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if not players.is_empty() else null
