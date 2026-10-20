## Trying clothes on: a panel along the bottom of the view with one big
## button per outfit, the body seen live above it.
##
## Owner request 2026-10-20: "go to showroom and try on different clothes".
## GDD §11 has no shop in the MVP and this is not one: no price, no badge, no
## owned state, everything is free. As with the cards of GDD §6 "Choice",
## every button is drawn the same way in the order the data lists them. The
## outfits are data/outfits.json; choosing one sets GameState.outfit, which
## the player's body listens to, so the change shows at once and goes into
## the journey file. A thumb or a mouse presses the buttons; keyboard and
## gamepad move focus along the row, and *Prev* and *Next* step it for them
## (and scroll the row for a thumb). Each control carries its label as its
## tooltip, the one field assistive tools can read in Godot 4.3 (see the
## settings screen and docs/DECISIONS.md).
extends Control

signal outfit_chosen(outfit_id: String)
signal closed

## Thumb-sized (GDD §11): never shorter than this.
const BUTTON_MIN := Vector2(240, 96)

var _ids := PackedStringArray()
var _buttons: Array[Button] = []
## The outfit button focus last sat on; Prev and Next step from here.
var _current := 0

@onready var _title: Label = %Title
@onready var _done: Button = %DoneButton
@onready var _prev: Button = %PrevButton
@onready var _next: Button = %NextButton
@onready var _row: HBoxContainer = %Outfits


func _ready() -> void:
	_title.text = Strings.t("wardrobe.title")
	_done.text = Strings.t("wardrobe.done")
	_done.tooltip_text = _done.text
	_prev.text = Strings.t("wardrobe.prev")
	_prev.tooltip_text = _prev.text
	_next.text = Strings.t("wardrobe.next")
	_next.tooltip_text = _next.text
	_done.pressed.connect(func() -> void: closed.emit())
	_prev.pressed.connect(func() -> void: step(-1))
	_next.pressed.connect(func() -> void: step(1))
	_ids = Outfits.ids()
	for index in _ids.size():
		var outfit_id := _ids[index]
		var button := Button.new()
		button.name = outfit_id
		button.text = Strings.t(Outfits.name_id_of(outfit_id))
		button.tooltip_text = button.text
		button.custom_minimum_size = BUTTON_MIN
		button.pressed.connect(_choose.bind(outfit_id))
		button.focus_entered.connect(func() -> void: _current = index)
		_row.add_child(button)
		_buttons.append(button)
	_wire_focus()
	var worn := GameState.outfit if Outfits.has(GameState.outfit) else Outfits.default_id()
	_current = maxi(0, _ids.find(worn))
	if not _buttons.is_empty():
		_buttons[_current].grab_focus()


func outfit_ids() -> PackedStringArray:
	return _ids.duplicate()


func outfit_buttons() -> Array[Button]:
	return _buttons.duplicate()


func button_for(outfit_id: String) -> Button:
	var index := _ids.find(outfit_id)
	return _buttons[index] if index >= 0 else null


## The outfit focus last sat on, as an index into outfit_ids().
func current_index() -> int:
	return _current


## Moves focus, and the row with it, one outfit along. The row has ends.
func step(delta: int) -> void:
	if _buttons.is_empty():
		return
	_current = clampi(_current + delta, 0, _buttons.size() - 1)
	_buttons[_current].grab_focus()


func _choose(outfit_id: String) -> void:
	GameState.set_outfit(outfit_id)
	outfit_chosen.emit(outfit_id)


## Up from any outfit is *Done*; down from *Done* is the row; left and right
## past the row's ends are the arrows. The rest Godot's focus finds itself.
func _wire_focus() -> void:
	if _buttons.is_empty():
		return
	var first := _buttons[0]
	var last := _buttons[_buttons.size() - 1]
	for button in _buttons:
		button.focus_neighbor_top = button.get_path_to(_done)
	first.focus_neighbor_left = first.get_path_to(_prev)
	last.focus_neighbor_right = last.get_path_to(_next)
	_prev.focus_neighbor_right = _prev.get_path_to(first)
	_next.focus_neighbor_left = _next.get_path_to(last)
	_done.focus_neighbor_bottom = _done.get_path_to(first)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()


## Hidden while the tree is paused so the pause menu and the settings have
## the screen to themselves, and back when play resumes.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		visible = false
	elif what == NOTIFICATION_UNPAUSED:
		visible = true
