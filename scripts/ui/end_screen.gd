## The end of the slice: black, one line, *Play again* and *Share your path*.
##
## CLAUDE_CODE_BRIEF.md §4.6: "Fade to black; one line in white, 24 dp:
## *The journey back begins again wherever you are.*; below it *Play again*
## only." The owner's expansion of 2026-10-20 puts the Path card of GDD §16a
## beside it: *Share your path* draws the card, saves it to the device and
## hands it to whatever the platform can do with a file (docs/DECISIONS.md
## "The Path card"). Play again wipes the journey (GameState) and returns to
## the title; the tester questionnaire is not here (docs/PLAYTEST_PROTOCOL.md).
extends Control

signal play_again_pressed
## The Path card was written to [param path] under user://.
signal path_card_saved(path: String)

const LINE_SIZE := 24
const APPEAR_SECONDS := 1.2

## Where the card is saved. Tests point this at a scratch file.
var card_path: String = PathCard.DEFAULT_SAVE_PATH

@onready var _line: Label = %Line
@onready var _buttons: Control = %Buttons
@onready var _play_again: Button = %PlayAgainButton
@onready var _share: Button = %ShareButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_line.text = Strings.t("end.line")
	_line.add_theme_font_size_override("font_size", LINE_SIZE)
	_play_again.text = Strings.t("end.play_again")
	_play_again.pressed.connect(_on_play_again)
	_share.text = Strings.t("end.share")
	_share.pressed.connect(_on_share)
	_line.modulate.a = 0.0
	_buttons.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_line, "modulate:a", 1.0, APPEAR_SECONDS)
	tween.tween_property(_buttons, "modulate:a", 1.0, APPEAR_SECONDS * 0.5)
	tween.tween_callback(_play_again.grab_focus)


func line_text() -> String:
	return _line.text


func _on_play_again() -> void:
	GameState.wipe()
	play_again_pressed.emit()


## Draws the Path card from the journey, saves it and hands it over.
func _on_share() -> void:
	var card := PathCard.new()
	card.render()
	if not card.save_png(card_path):
		return
	_hand_over(card)
	path_card_saved.emit(card_path)


## Godot 4.3 has no share sheet without a platform plugin, so the saved file
## goes to what each platform does with one: the web build downloads it;
## Android and the desktops open it in the system's own viewer, which has the
## share button. Headless, as in the tests, there is nothing to hand it to.
func _hand_over(card: PathCard) -> void:
	if OS.has_feature("web"):
		var png := card.image().save_png_to_buffer()
		JavaScriptBridge.download_buffer(png, card_path.get_file(), "image/png")
	elif DisplayServer.get_name() != "headless":
		OS.shell_open(ProjectSettings.globalize_path(card_path))
