## Choice cards: a speaker, a line, and two or three full sentences to tap.
##
## GDD §6 "Choice": two or three options, full sentences, shown as cards. No
## timer. No option is labelled good or bad, and no icon hints at a correct
## answer. CLAUDE_CODE_BRIEF.md §10: no colour difference, no ordering
## convention — every card here is drawn by the same style in the order the
## data lists them. A line with no cards is dismissed by a tap anywhere.
extends Control

signal card_pressed(index: int)
signal dismissed

const CARD_MIN_HEIGHT := 84.0
const CHOICE_CARD := preload("res://scripts/ui/choice_card.gd")

var _dialogue: Dialogue = null
var _card_count := 0

@onready var _dim: ColorRect = %Dim
@onready var _panel: PanelContainer = %Panel
@onready var _speaker: Label = %Speaker
@onready var _line: Label = %Line
@onready var _cards: VBoxContainer = %Cards


func _ready() -> void:
	visible = false
	_dim.gui_input.connect(_on_tap_outside)
	_panel.gui_input.connect(_on_tap_outside)


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
	_cards.visible = _card_count > 0
	visible = true


func card_count() -> int:
	return _card_count


func card_button(index: int) -> PanelContainer:
	return _cards.get_child(index) as PanelContainer


func _make_card(index: int, card: Dictionary) -> PanelContainer:
	var button: PanelContainer = CHOICE_CARD.new()
	button.text = Strings.t(card.get("text_id", ""))
	button.custom_minimum_size = Vector2(0.0, CARD_MIN_HEIGHT)
	button.pressed.connect(func() -> void: card_pressed.emit(index))
	return button


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
