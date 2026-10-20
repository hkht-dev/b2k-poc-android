## The end of the slice: black, one line, *Play again*.
##
## CLAUDE_CODE_BRIEF.md §4.6: "Fade to black; one line in white, 24 dp:
## *The journey back begins again wherever you are.*; below it *Play again*
## only." Play again wipes the journey (GameState) and returns to the title;
## the tester questionnaire is not here (docs/PLAYTEST_PROTOCOL.md).
extends Control

signal play_again_pressed

const LINE_SIZE := 24
const APPEAR_SECONDS := 1.2

@onready var _line: Label = %Line
@onready var _play_again: Button = %PlayAgainButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_line.text = Strings.t("end.line")
	_line.add_theme_font_size_override("font_size", LINE_SIZE)
	_play_again.text = Strings.t("end.play_again")
	_play_again.pressed.connect(_on_play_again)
	_line.modulate.a = 0.0
	_play_again.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_line, "modulate:a", 1.0, APPEAR_SECONDS)
	tween.tween_property(_play_again, "modulate:a", 1.0, APPEAR_SECONDS * 0.5)
	tween.tween_callback(_play_again.grab_focus)


func line_text() -> String:
	return _line.text


func _on_play_again() -> void:
	GameState.wipe()
	play_again_pressed.emit()
