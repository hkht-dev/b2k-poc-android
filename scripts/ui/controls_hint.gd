## The controls card: one screen, by device, with a diagram.
##
## docs/BRIEF_AMENDMENT_1.md §A5. Shown on first launch (until *Play again*)
## and always available from the pause menu. The scheme follows the platform —
## mobile, web, desktop — and switches to the gamepad scheme when one is
## connected. It says how to move, look, walk-there, use and hum, and nothing
## about where to go (CLAUDE_CODE_BRIEF.md §4.3).
extends Control

signal dismissed

const SETTING_SEEN := "controls_seen"
## The card's lines in order; each is the string id `controls.<scheme>.<key>`.
const LINE_KEYS := ["move", "look", "walk_there", "use", "hum", "places", "drive"]

## Opened from the pause menu: the button says Close and nothing is recorded.
var from_pause := false

@onready var _title: Label = %Title
@onready var _diagram: Control = %Diagram
@onready var _lines: VBoxContainer = %Lines
@onready var _button: Button = %GotItButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var scheme := detect_scheme()
	_title.text = Strings.t("controls.title")
	for child in _lines.get_children():
		child.queue_free()
	for key in LINE_KEYS:
		var label := Label.new()
		label.text = Strings.t("controls.%s.%s" % [scheme, key])
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 24)
		_lines.add_child(label)
	_diagram.scheme = scheme
	_diagram.queue_redraw()
	_button.text = Strings.t("controls.close" if from_pause else "controls.got_it")
	_button.pressed.connect(_on_button)
	_button.grab_focus()


## "touch", "desktop" or "gamepad" (§A5).
static func detect_scheme() -> String:
	if not Input.get_connected_joypads().is_empty():
		return "gamepad"
	if OS.has_feature("mobile"):
		return "touch"
	if OS.has_feature("web") and DisplayServer.is_touchscreen_available():
		return "touch"
	return "desktop"


static func already_seen() -> bool:
	return GameState.settings.get(SETTING_SEEN, false) == true


func current_scheme() -> String:
	return _diagram.scheme


func _on_button() -> void:
	if not from_pause:
		GameState.settings[SETTING_SEEN] = true
		GameState.save()
	dismissed.emit()
