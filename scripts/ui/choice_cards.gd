## Choice cards: a speaker, a line, and two or three full sentences to tap.
##
## GDD §6 "Choice": two or three options, full sentences, shown as cards. No
## timer. No option is labelled good or bad, and no icon hints at a correct
## answer. CLAUDE_CODE_BRIEF.md §10: no colour difference, no ordering
## convention — every card here is drawn by the same style in the order the
## data lists them. A line with no cards is dismissed by a tap anywhere.
##
## Every device answers (GDD §11 "Controls", owner request 2026-10-20): on
## touch the cards are thumb-high with room between them; at a keyboard the
## number keys 1–3 are the cards in order and Esc dismisses a line that has
## none (raw keycodes, so the input map stays as it is); on a gamepad the
## first card takes focus when a line appears, the d-pad or stick moves it
## and the accept button chooses. On desktop nothing is focused until an
## arrow or Tab is pressed, so a card never looks picked out by default.
extends Control

signal card_pressed(index: int)
signal dismissed

const CHOICE_CARD := preload("res://scripts/ui/choice_card.gd")
const CONTROLS_HINT := preload("res://scripts/ui/controls_hint.gd")
const SCHEME_TOUCH := "touch"
const SCHEME_GAMEPAD := "gamepad"
## Minimum card height: the theme's button height, or a thumb's on touch.
const CARD_MIN_HEIGHT := 72.0
const CARD_MIN_HEIGHT_TOUCH := 96.0
const CARD_GAP := 12
const CARD_GAP_TOUCH := 16
## The keys that choose a card, in card order; each list is one card's keys.
const CARD_KEYS := [[KEY_1, KEY_KP_1], [KEY_2, KEY_KP_2], [KEY_3, KEY_KP_3]]
const DISMISS_KEY := KEY_ESCAPE
## Actions that, with nothing focused, put the focus on a card first.
const FOCUS_FORWARD_ACTIONS := ["ui_down", "ui_focus_next"]
const FOCUS_BACKWARD_ACTIONS := ["ui_up", "ui_focus_prev"]

var _dialogue: Dialogue = null
var _card_count := 0
var _scheme := SCHEME_TOUCH

@onready var _dim: ColorRect = %Dim
@onready var _panel: PanelContainer = %Panel
@onready var _speaker: Label = %Speaker
@onready var _line: Label = %Line
@onready var _cards: VBoxContainer = %Cards


func _ready() -> void:
	visible = false
	_dim.gui_input.connect(_on_tap_outside)
	_panel.gui_input.connect(_on_tap_outside)
	apply_scheme(CONTROLS_HINT.detect_scheme())


## Drives these cards from a dialogue runner: lines appear as it shows them,
## taps go back to it, and the cards hide when it finishes.
func bind(dialogue: Dialogue) -> void:
	unbind()
	_dialogue = dialogue
	dialogue.line_shown.connect(_on_line_shown)
	dialogue.finished.connect(_on_finished)
	card_pressed.connect(dialogue.choose)
	dismissed.connect(dialogue.dismiss)


func unbind() -> void:
	if _dialogue == null:
		return
	_dialogue.line_shown.disconnect(_on_line_shown)
	_dialogue.finished.disconnect(_on_finished)
	card_pressed.disconnect(_dialogue.choose)
	dismissed.disconnect(_dialogue.dismiss)
	_dialogue = null


## Sizes the cards for "touch", "desktop" or "gamepad" (TouchControls tells
## the Place's cards; the debug panel's detect it).
func apply_scheme(scheme: String) -> void:
	_scheme = scheme
	_cards.add_theme_constant_override("separation", card_gap())
	for card: Control in _cards.get_children():
		card.custom_minimum_size = Vector2(0.0, card_min_height())


func scheme() -> String:
	return _scheme


func card_min_height() -> float:
	return CARD_MIN_HEIGHT_TOUCH if _scheme == SCHEME_TOUCH else CARD_MIN_HEIGHT


func card_gap() -> int:
	return CARD_GAP_TOUCH if _scheme == SCHEME_TOUCH else CARD_GAP


## Lays out one line. Every word comes from the string table by id.
func show_line(line: Dictionary) -> void:
	var speaker: String = line.get("speaker", "")
	_speaker.text = Strings.t("speaker." + speaker) if not speaker.is_empty() else ""
	_speaker.visible = not _speaker.text.is_empty()
	_line.text = Strings.t(line.get("text_id", ""))

	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	var cards: Array = line.get("cards", [])
	_card_count = cards.size()
	for index in cards.size():
		_cards.add_child(_make_card(index, cards[index]))
	_chain_focus()
	_cards.visible = _card_count > 0
	visible = true
	if _scheme == SCHEME_GAMEPAD and _card_count > 0:
		card_button(0).grab_focus()


func card_count() -> int:
	return _card_count


func card_button(index: int) -> PanelContainer:
	return _cards.get_child(index) as PanelContainer


## The card with the focus, or -1.
func focused_card() -> int:
	for index in _card_count:
		if card_button(index).has_focus():
			return index
	return -1


func _make_card(index: int, card: Dictionary) -> PanelContainer:
	var button: PanelContainer = CHOICE_CARD.new()
	button.text = Strings.t(card.get("text_id", ""))
	button.custom_minimum_size = Vector2(0.0, card_min_height())
	button.pressed.connect(func() -> void: card_pressed.emit(index))
	return button


## Up and down walk the cards in order and wrap, whatever their heights.
func _chain_focus() -> void:
	for index in _card_count:
		var card := card_button(index)
		var above := card_button((index - 1 + _card_count) % _card_count)
		var below := card_button((index + 1) % _card_count)
		card.focus_neighbor_top = card.get_path_to(above)
		card.focus_neighbor_bottom = card.get_path_to(below)
		card.focus_previous = card.focus_neighbor_top
		card.focus_next = card.focus_neighbor_bottom


func _unhandled_input(event: InputEvent) -> void:
	# The cards never pause the world; when something else has (the pause
	# menu over them), the keys are that thing's.
	if not visible or get_tree().paused:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		for index in mini(_card_count, CARD_KEYS.size()):
			if (CARD_KEYS[index] as Array).has(event.keycode):
				get_viewport().set_input_as_handled()
				card_pressed.emit(index)
				return
		if event.keycode == DISMISS_KEY and _card_count == 0:
			get_viewport().set_input_as_handled()
			dismissed.emit()
			return
	if _card_count == 0 or focused_card() != -1:
		return
	for action: String in FOCUS_FORWARD_ACTIONS:
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			card_button(0).grab_focus()
			return
	for action: String in FOCUS_BACKWARD_ACTIONS:
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			card_button(_card_count - 1).grab_focus()
			return


func _on_tap_outside(event: InputEvent) -> void:
	if _card_count > 0:
		return
	var tapped: bool = (
		(event is InputEventMouseButton and event.pressed)
		or (event is InputEventScreenTouch and event.pressed)
	)
	if tapped:
		dismissed.emit()


func _on_line_shown(_line_id: String, line: Dictionary) -> void:
	show_line(line)


func _on_finished() -> void:
	visible = false
