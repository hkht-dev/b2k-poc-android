## Counting with him: coins to tap, one by one, and no number anywhere.
##
## GDD §7 "The Counting Man" (a): "count with him (a 30-second mini-game;
## the total is 108)". The thirty seconds are how long a hundred and eight
## taps take, not a limit: there is no countdown, no clock and no score
## (CLAUDE.md), and GDD §11 says the mini-game can be skipped, so a button
## stops it with nothing lost. Nothing shows a number until the last coin,
## when the end line says the total in words, from the string table. Enter,
## Space or the gamepad's A taps the next coin (GDD §11: D-pad + A); Escape
## or B stops.
extends Control

## The last coin was tapped. The man's script fires the event the quest reads.
signal finished
## The screen is done with, finished or stopped; whoever opened it frees it.
signal closed

## Brass: GDD §10 Hollow Vale's ochre and timber. Not peacock blue, not magenta.
const COIN_COLOUR := Color(0.72, 0.56, 0.26, 1.0)
const COIN_RIM := Color(0.5, 0.37, 0.16, 1.0)
const COIN_SIZE := Vector2(64, 64)
const TAKEN_ALPHA := 0.18
const ACCEPT_ACTIONS := ["ui_accept", "contextual"]
const CANCEL_ACTION := "ui_cancel"

## How many coins there are to tap. The total is said in words by
## `total_text_id`, never shown as a figure.
@export_range(1, 400, 1) var coin_count := 108
@export var hint_text_id := "count.hint"
@export var total_text_id := "count.total"
@export var stop_text_id := "count.stop"
@export var done_text_id := "count.done"

var _coins: Array[Button] = []
var _taken := 0
var _finished := false
var _style: StyleBoxFlat = null

@onready var _dim: ColorRect = %Dim
@onready var _hint: Label = %Hint
@onready var _grid: GridContainer = %Coins
@onready var _stop: Button = %StopButton


func _ready() -> void:
	_hint.text = Strings.t(hint_text_id)
	_stop.text = Strings.t(stop_text_id)
	_stop.focus_mode = Control.FOCUS_NONE
	_stop.pressed.connect(close)
	_dim.gui_input.connect(_on_dim_input)
	_style = StyleBoxFlat.new()
	_style.bg_color = COIN_COLOUR
	_style.border_color = COIN_RIM
	_style.set_border_width_all(3)
	_style.set_corner_radius_all(int(COIN_SIZE.x / 2.0))
	for index in coin_count:
		var coin := _make_coin(index)
		_grid.add_child(coin)
		_coins.append(coin)


## Taps coin [param index]: it is taken and stays taken. The last one ends it.
func tap(index: int) -> void:
	if _finished or index < 0 or index >= _coins.size():
		return
	var coin := _coins[index]
	if coin.disabled:
		return
	coin.disabled = true
	coin.modulate.a = TAKEN_ALPHA
	_taken += 1
	if _taken >= coin_count:
		_finish()


## Keyboard and gamepad: the first coin not yet taken.
func tap_next() -> void:
	for index in _coins.size():
		if not _coins[index].disabled:
			tap(index)
			return


## Stops or dismisses the screen. Stopping early frees nobody.
func close() -> void:
	closed.emit()


func is_finished() -> bool:
	return _finished


## How many are left to tap. For tests; never shown.
func coins_left() -> int:
	return coin_count - _taken


func coin(index: int) -> Button:
	return _coins[index]


func hint_text() -> String:
	return _hint.text


func stop_button() -> Button:
	return _stop


func _finish() -> void:
	_finished = true
	_grid.visible = false
	_hint.text = Strings.t(total_text_id)
	_stop.text = Strings.t(done_text_id)
	finished.emit()


func _make_coin(index: int) -> Button:
	var coin := Button.new()
	coin.custom_minimum_size = COIN_SIZE
	coin.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		coin.add_theme_stylebox_override(state, _style)
	coin.pressed.connect(func() -> void: tap(index))
	return coin


func _on_dim_input(event: InputEvent) -> void:
	if not _finished:
		return
	var tapped: bool = (
		(event is InputEventMouseButton and event.pressed)
		or (event is InputEventScreenTouch and event.pressed)
	)
	if tapped:
		close()


## Ahead of the place's own handling of E and A, so a press here taps a coin
## and never reaches the contextual button under the screen.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	# Marked handled before acting: closing takes this screen out of the tree.
	var viewport := get_viewport()
	for action in ACCEPT_ACTIONS:
		if event.is_action_pressed(action):
			viewport.set_input_as_handled()
			if _finished:
				close()
			else:
				tap_next()
			return
		if event.is_action_released(action):
			viewport.set_input_as_handled()
			return
	if event.is_action_pressed(CANCEL_ACTION):
		viewport.set_input_as_handled()
		close()
