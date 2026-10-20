## Persistent root of the game. Owns the one screen that is currently on
## screen and swaps it on request.
##
## Repository layout puts this in scenes/core alongside GameState, FlagStore and
## the debug panel (CLAUDE_CODE_BRIEF.md §2). Those arrive in P2; this is only
## the screen swapper they will hang off, so nothing out of scope is scaffolded
## here (§10).
extends Node

const TITLE_SCREEN := "res://scenes/ui/TitleScreen.tscn"
const FIRST_PLAY_SCREEN := "res://scenes/street/Street.tscn"
const CONTROLS_HINT := "res://scenes/ui/ControlsHint.tscn"
const END_SCREEN := "res://scenes/ui/EndScreen.tscn"
const DEBUG_PANEL := preload("res://scenes/core/DebugPanel.tscn")
const CONTROLS_HINT_SCRIPT := preload("res://scripts/ui/controls_hint.gd")

var _current: Node = null
var _debug_panel: Control = null

@onready var _screen_root: Node = $ScreenRoot
@onready var _overlay: CanvasLayer = $Overlay


func _ready() -> void:
	show_screen(TITLE_SCREEN)


## Replaces the current screen with the scene at [param path]. Returns the new
## screen, or null if the scene could not be loaded.
func show_screen(path: String) -> Node:
	if not ResourceLoader.exists(path):
		push_error("Main: no scene at %s" % path)
		return null
	# exists() only says a file is there. A scene whose script fails to compile,
	# or that is itself malformed, still loads as null — and the player would
	# get a blank screen instead of an error.
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Main: %s is not a scene that could be loaded" % path)
		return null
	var screen: Node = packed.instantiate()
	if _current != null:
		_screen_root.remove_child(_current)
		_current.queue_free()
	_screen_root.add_child(screen)
	_current = screen
	_connect_screen(screen)
	return screen


func current_screen() -> Node:
	return _current


## Wires the signals a screen may expose. A screen that does not have one is
## simply left alone, so screens stay independent of this script.
func _connect_screen(screen: Node) -> void:
	if screen.has_signal("begin_pressed"):
		screen.connect("begin_pressed", _on_begin_pressed)
	if screen.has_signal("back_pressed"):
		screen.connect("back_pressed", _on_back_pressed)
	if screen.has_signal("debug_requested"):
		screen.connect("debug_requested", open_debug_panel)
	if screen.has_signal("dismissed"):
		screen.connect("dismissed", _on_hint_dismissed)
	if screen.has_signal("slice_ended"):
		screen.connect("slice_ended", _on_slice_ended)
	if screen.has_signal("play_again_pressed"):
		screen.connect("play_again_pressed", _on_back_pressed)


## Shows the tester's panel over whatever is on screen. One at a time.
func open_debug_panel() -> void:
	if _debug_panel != null:
		return
	_debug_panel = DEBUG_PANEL.instantiate()
	_debug_panel.closed.connect(close_debug_panel)
	_overlay.add_child(_debug_panel)


func close_debug_panel() -> void:
	if _debug_panel == null:
		return
	_overlay.remove_child(_debug_panel)
	_debug_panel.queue_free()
	_debug_panel = null


func debug_panel() -> Control:
	return _debug_panel


func _on_begin_pressed() -> void:
	if CONTROLS_HINT_SCRIPT.already_seen():
		show_screen(FIRST_PLAY_SCREEN)
	else:
		show_screen(CONTROLS_HINT)


func _on_hint_dismissed() -> void:
	show_screen(FIRST_PLAY_SCREEN)


func _on_back_pressed() -> void:
	show_screen(TITLE_SCREEN)


## The street has faded to black (CLAUDE_CODE_BRIEF.md §4.6).
func _on_slice_ended(_reason: String) -> void:
	show_screen(END_SCREEN)
