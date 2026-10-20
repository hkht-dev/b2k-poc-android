## Sarang, the musician whose instrument has a string missing.
##
## GDD §4: "Thin, nervous, the only one who cares about the music.
## Investigation route: he knows the melody's first bar." GDD §7 Investigate
## step 4, "Sarang teaches you the first bar"; Mediate step 3, the missing
## string, which another part of the street brings (`sarang_string_given`).
##
## *Talk* opens the first of `entry_lines` whose requirements hold (the order
## is data on the scene, the requirements live in data/dialogue, as with
## Gopal), skipping any line whose `skip_when` flag holds: that is how a line
## is said once (his thanks) or stops being offered (the string, once given).
## The string itself comes from Nanda's flat as `has_sarang_string`; handing
## it over is a card that sets `sarang_string_given`, and the gap in his
## instrument fills. When the dialogue shows one of `lessons` (line id -> bar
## id in data/song.json) the SongScreen opens on that bar over the place,
## with the tree paused as the pause menu pauses it; finishing at any quality
## sets the bar's `taught_flag` and writes its journey line, both from the
## song data. He never grades: the quality only decides which of his lines
## the screen says (GDD §16a: "never as a number").
extends Node3D

signal talked(line_id: String)
## A lesson ended, with what the player's hands did as one quality in 0–1.
## For the world to answer; never for the screen.
signal lesson_finished(bar_id: String, quality: float)

const SONG_SCREEN := preload("res://scenes/ui/SongScreen.tscn")

## Dialogue line ids to try in order; the first whose `requires` hold opens.
@export var entry_lines: PackedStringArray = PackedStringArray()
## Dialogue line id -> flag: the entry line is not offered while the flag holds.
@export var skip_when: Dictionary = {}
## Dialogue line id -> bar id in data/song.json: showing the line opens the
## lesson on that bar.
@export var lessons: Dictionary = {}
## The flag the hand-over sets, and the string that appears on his
## instrument when it does (a node beside him in the generated street).
@export var string_flag := "sarang_string_given"
## The item the player is holding when they give it (`carryables`).
@export var string_item := "string"
@export var mended_string: NodePath

var _screen: Control = null
var _was_paused := false

@onready var _talk: Interactable = %Talk
@onready var _overlay: CanvasLayer = %Overlay


func _ready() -> void:
	_talk.used.connect(_on_talk)
	Content.dialogue.line_shown.connect(_on_line_shown)
	GameState.flag_changed.connect(_on_flag_changed)
	_show_mended_string()


func song_screen() -> Control:
	return _screen


## Opens the lesson on [param bar_id] with [param speaker] saying [param
## text_id] over the demonstration. Returns the screen (the one already open,
## if there is one).
func open_lesson(bar_id: String, speaker: String = "", text_id: String = "") -> Control:
	if _screen != null:
		return _screen
	_screen = SONG_SCREEN.instantiate()
	_screen.set_bar(bar_id)
	if not text_id.is_empty():
		_screen.set_header(speaker, text_id)
	_screen.set_on_finished(_on_lesson_finished.bind(bar_id))
	_screen.closed.connect(_on_screen_closed)
	_overlay.add_child(_screen)
	_was_paused = get_tree().paused
	get_tree().paused = true
	return _screen


func _on_talk(_player: Node3D) -> void:
	for line_id in entry_lines:
		if skip_when.has(line_id) and GameState.has_flag(str(skip_when[line_id])):
			continue
		if Content.dialogue.start(line_id):
			talked.emit(line_id)
			return


func _on_flag_changed(flag: String, is_set: bool) -> void:
	if flag != string_flag:
		return
	_show_mended_string()
	# The card gives him the string; the hand it came out of is this half.
	# Without it the player walks away still holding what they handed over,
	# and a full hand withdraws every pick-up for the rest of the journey.
	if not is_set:
		return
	var player := _find_player()
	if player != null and player.is_carrying(string_item):
		player.put_down()


## The world's answer to the string: the gap in the instrument is strung.
func _show_mended_string() -> void:
	if mended_string.is_empty():
		return
	var mended := get_node_or_null(mended_string) as Node3D
	if mended != null:
		mended.visible = GameState.has_flag(string_flag)


## The dialogue reached a lesson line: the cards show it this frame, then it
## is dismissed and the screen takes over, with his words as its header.
func _on_line_shown(line_id: String, line: Dictionary) -> void:
	if _screen != null or not lessons.has(line_id):
		return
	_dismiss_line.call_deferred(line_id)
	open_lesson(str(lessons[line_id]), str(line.get("speaker", "")), str(line.get("text_id", "")))


func _dismiss_line(line_id: String) -> void:
	if Content.dialogue.current_line_id() == line_id:
		Content.dialogue.dismiss()


func _on_lesson_finished(quality: float, bar_id: String) -> void:
	var bar := Song.bar(bar_id)
	var flag := str(bar.get("taught_flag", ""))
	if not flag.is_empty():
		GameState.set_flag(flag)
	GameState.add_journey_line(str(bar.get("journey_line_id", "")))
	lesson_finished.emit(bar_id, quality)


func _on_screen_closed() -> void:
	_screen = null
	# As it was: a lesson opened under the pause menu leaves the menu's pause.
	get_tree().paused = _was_paused


func _find_player() -> Node3D:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if not players.is_empty() else null
