## Vasanti, padlocking the community garden gate.
##
## GDD §4 ("to fence the fruit tree; to trust again") and §7 "The Fence".
## *Talk* opens the first of `entry_lines` whose requirements the flags meet,
## the order data on the scene as with Gopal. *Place* takes a fruit from the
## player's hand instead of Talk while they hold one (the Interactable's
## `requires` is `carrying_fruit`, data) and fires `fruit_given`; the quest
## decides what that means. When the quest says she has given fruit (the
## `fixed` branch sets `has_fruit`), the fruit goes into the player's hand and
## she says so. She never judges: every line is chosen by flags.
extends Node3D

signal talked(line_id: String)
signal fruit_received(player: Node3D)

## Dialogue line ids to try in order; the first whose `requires` hold opens.
@export var entry_lines: PackedStringArray = PackedStringArray()
## The carryable the player hands her, and she hands over.
@export var fruit_item := "fruit"
## Fired when the player places a fruit with her.
@export var give_event := "fruit_given"
## Set by the quest when she gives the player fruit.
@export var gift_flag := "has_fruit"
## What she holds once given a fruit.
@export var fruit_scene: PackedScene

@onready var _talk: Interactable = %Talk
@onready var _place: Interactable = %Place
@onready var _figure: CharacterRig = %Figure


func _ready() -> void:
	_talk.used.connect(_on_talk)
	_place.used.connect(_on_place)
	GameState.flag_changed.connect(_on_flag_changed)
	if GameState.has_event(give_event):
		_figure.carry(true, fruit_scene)


func _physics_process(_delta: float) -> void:
	var offering := _can_receive(_find_player())
	_place.enabled = offering
	_talk.enabled = not offering


## She takes a fruit while the player holds one and none has changed hands.
func _can_receive(player: Node3D) -> bool:
	if player == null or not player.is_carrying(fruit_item):
		return false
	return not GameState.has_event(give_event) and not GameState.has_flag(gift_flag)


func _on_talk(_player: Node3D) -> void:
	for line_id in entry_lines:
		if Content.dialogue.start(line_id):
			talked.emit(line_id)
			return


func _on_place(player: Node3D) -> void:
	if not _can_receive(player):
		return
	player.put_down()
	_figure.carry(true, fruit_scene)
	GameState.fire_event(give_event)
	fruit_received.emit(player)
	_on_talk(player)


## The quest says she gives fruit: it goes into the player's hand, with a line.
func _on_flag_changed(flag: String, is_set: bool) -> void:
	if flag != gift_flag or not is_set:
		return
	var player := _find_player()
	if player == null:
		return
	if not player.is_carrying():
		player.carry(fruit_item)
	_on_talk(player)


func _find_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if not players.is_empty() else null
