## A wisdom card: one verse, its source, a two-sentence meaning, and *Read
## more*, which unfolds a longer note kept in the app, offline.
##
## GDD §6 "Optional wisdom" and §9 "Card format": "Verse reference · the
## licensed translation · a two-sentence gloss · Read more (a 200–300 word
## note ... offline in the app) · a Sources line". The game pauses while a
## card is open (§9), so this processes always. Every word is a string id
## from the card's row in data/wisdom.json (scripts/core/wisdom.gd). A card
## comments on the situation, never on the player's choice (§9 rules).
extends Control

signal expanded
signal closed

const VERSE_SIZE := 28

var _card_id := ""

@onready var _verse: Label = %Verse
@onready var _source: Label = %Source
@onready var _meaning: Label = %Meaning
@onready var _read_more: Button = %ReadMoreButton
@onready var _more: ScrollContainer = %More
@onready var _more_text: Label = %MoreText
@onready var _close: Button = %CloseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_verse.add_theme_font_size_override("font_size", VERSE_SIZE)
	_read_more.text = Strings.t("wisdom.read_more")
	_read_more.tooltip_text = _read_more.text
	_close.text = Strings.t("wisdom.close")
	_close.tooltip_text = _close.text
	_more.visible = false
	_read_more.pressed.connect(read_more)
	_close.pressed.connect(close)
	_read_more.grab_focus()


## Fills the card from its row. An unknown id shows its bracketed marker
## (Strings.t), so a data slip is visible in a playtest, never blank.
func show_card(card_id: String) -> void:
	_card_id = card_id
	var row := Wisdom.card(card_id)
	_verse.text = Strings.t(str(row.get("verse_id", "")))
	_source.text = Strings.t(str(row.get("source_id", "")))
	_meaning.text = Strings.t(str(row.get("meaning_id", "")))
	_more_text.text = Strings.t(str(row.get("more_id", "")))
	_more.visible = false
	_read_more.visible = true
	_read_more.grab_focus()


func card_id() -> String:
	return _card_id


func verse_text() -> String:
	return _verse.text


func source_text() -> String:
	return _source.text


func meaning_text() -> String:
	return _meaning.text


func more_text() -> String:
	return _more_text.text


func is_expanded() -> bool:
	return _more.visible


## *Read more*: the note unfolds in place and the button has done its work.
func read_more() -> void:
	if _more.visible:
		return
	_more.visible = true
	_read_more.visible = false
	_close.grab_focus()
	expanded.emit()


func close() -> void:
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
