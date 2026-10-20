## Title screen. Shows the game's name and one way in.
##
## GDD §11 "HUD": nothing is on screen that does not need to be. No tagline, no
## instructions and nothing that frames this as a spiritual game
## (CLAUDE_CODE_BRIEF.md §0).
extends Control

signal begin_pressed
## Five taps on the title within the window (CLAUDE_CODE_BRIEF.md §0 item 6).
signal debug_requested

const DEBUG_TAPS := 5
const DEBUG_TAP_WINDOW_MS := 2000

var _tap_times: Array[int] = []

@onready var _title: Label = %Title
@onready var _begin: Button = %BeginButton
@onready var _build: Label = %BuildLabel


func _ready() -> void:
	_title.text = Strings.t("app.title")
	_begin.text = Strings.t("title.begin")
	_build.text = Strings.t("title.build_label") % _build_name()
	_begin.pressed.connect(func() -> void: begin_pressed.emit())
	_begin.grab_focus()
	_title.mouse_filter = Control.MOUSE_FILTER_STOP
	_title.gui_input.connect(_on_title_input)


## Counts presses on the title. Five inside the window open the debug panel;
## anything slower is just someone poking the screen.
func _on_title_input(event: InputEvent) -> void:
	# One real press arrives twice: the project emulates touch from the mouse
	# (project.godot "pointing/emulate_touch_from_mouse"), so the emulated
	# twin comes first and the original follows. Counting both made five taps
	# out of three. The twin carries the emulation device id; it is ignored.
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var pressed: bool = (
		(event is InputEventMouseButton and event.pressed)
		or (event is InputEventScreenTouch and event.pressed)
	)
	if not pressed:
		return
	var now := Time.get_ticks_msec()
	_tap_times.append(now)
	while not _tap_times.is_empty() and now - _tap_times[0] > DEBUG_TAP_WINDOW_MS:
		_tap_times.pop_front()
	if _tap_times.size() >= DEBUG_TAPS:
		_tap_times.clear()
		debug_requested.emit()


## The version from project.godot, so a tester can name the build they played
## (CLAUDE_CODE_BRIEF.md §8 playtest reporting).
func _build_name() -> String:
	var version: Variant = ProjectSettings.get_setting("application/config/version", "")
	return str(version)
