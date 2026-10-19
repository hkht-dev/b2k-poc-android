## Persistent root of the game. Owns the one screen that is currently on
## screen and swaps it on request.
##
## Repository layout puts this in scenes/core alongside GameState, FlagStore and
## the debug panel (CLAUDE_CODE_BRIEF.md §2). Those arrive in P2; this is only
## the screen swapper they will hang off, so nothing out of scope is scaffolded
## here (§10).
extends Node

const TITLE_SCREEN := "res://scenes/ui/TitleScreen.tscn"
# PLACEHOLDER: P1 replaces this with res://scenes/street/Street.tscn.
const FIRST_PLAY_SCREEN := "res://scenes/core/NotYetBuilt.tscn"

var _current: Node = null

@onready var _screen_root: Node = $ScreenRoot


func _ready() -> void:
	show_screen(TITLE_SCREEN)


## Replaces the current screen with the scene at [param path]. Returns the new
## screen, or null if the scene could not be loaded.
func show_screen(path: String) -> Node:
	if not ResourceLoader.exists(path):
		push_error("Main: no scene at %s" % path)
		return null
	var packed: PackedScene = load(path)
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


func _on_begin_pressed() -> void:
	show_screen(FIRST_PLAY_SCREEN)


func _on_back_pressed() -> void:
	show_screen(TITLE_SCREEN)
