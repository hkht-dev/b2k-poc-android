## Pause: resume, or see the controls again.
##
## GDD §11 lists the pause menu's contents (Your journey, settings, quit);
## *Your journey* is here since P5, the rest arrive in P6.
## docs/BRIEF_AMENDMENT_1.md §A5 asks for *Controls* to be reachable here
## always, so the menu exists now with that and *Resume*.
## *Set a lamp here* (GDD §16a) came with the owner's 2026-10-20 expansion.
extends Control

signal resumed
signal controls_requested
signal settings_requested
signal map_toggled(on: bool)
## *Set a lamp here*: the Place opens the twelve lines (GDD §16a).
signal lamp_requested

const MINIMAP := preload("res://scripts/ui/minimap.gd")
const GARDEN_SCREEN := preload("res://scenes/ui/GardenScreen.tscn")

var _garden_overlay: Control = null

@onready var _title: Label = %Title
@onready var _resume: Button = %ResumeButton
@onready var _controls: Button = %ControlsButton
@onready var _map: Button = %MapButton
@onready var _settings: Button = %SettingsButton
@onready var _garden: Button = %GardenButton
@onready var _lamp: Button = %LampButton
@onready var _now: Label = %Now
@onready var _journey_title: Label = %JourneyTitle
@onready var _journey: VBoxContainer = %Journey
@onready var _noticed_title: Label = %NoticedTitle
@onready var _noticed: VBoxContainer = %Noticed


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_title.text = Strings.t("pause.title")
	_resume.text = Strings.t("pause.resume")
	_controls.text = Strings.t("pause.controls")
	_resume.pressed.connect(func() -> void: resumed.emit())
	_controls.pressed.connect(func() -> void: controls_requested.emit())
	_settings.text = Strings.t("pause.settings")
	_settings.pressed.connect(func() -> void: settings_requested.emit())
	_garden.text = Strings.t("pause.garden")
	_garden.pressed.connect(_open_garden)
	_lamp.text = Strings.t("pause.set_lamp")
	_lamp.pressed.connect(func() -> void: lamp_requested.emit())
	_refresh_map_label()
	_map.pressed.connect(_on_map)
	_now.text = now_line()
	_fill_journey()
	_fill_noticed()
	_resume.grab_focus()


## *Your journey* (GDD §6 "Choice", CLAUDE_CODE_BRIEF.md §4.5): the lines the
## journey has recorded, in order, each from the string table. Hidden until
## there is one.
func _fill_journey() -> void:
	for child in _journey.get_children():
		child.queue_free()
	_journey_title.text = Strings.t("pause.journey")
	var lines: PackedStringArray = GameState.journey_lines
	_journey_title.visible = not lines.is_empty()
	_journey.visible = not lines.is_empty()
	for line_id in lines:
		var label := Label.new()
		label.text = Strings.t(line_id)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 18)
		_journey.add_child(label)


func journey_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for child in _journey.get_children():
		out.append((child as Label).text)
	return out


## *Noticed* (GDD §6 "Tells", §16a): under *Your journey*, the sentence each
## Tell was seen in, in the order seen, each from the string table through
## the tell's row in data/tells.json. Hidden until there is one; never a
## count.
func _fill_noticed() -> void:
	for child in _noticed.get_children():
		child.queue_free()
	_noticed_title.text = Strings.t("pause.noticed")
	var ids: PackedStringArray = GameState.noticed
	_noticed_title.visible = not ids.is_empty()
	_noticed.visible = not ids.is_empty()
	for tell_id in ids:
		var label := Label.new()
		label.text = Strings.t(Tells.sentence_id_of(tell_id))
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 18)
		_noticed.add_child(label)


func noticed_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for child in _noticed.get_children():
		out.append((child as Label).text)
	return out


## The single line at the top of the pause menu saying what the player is
## doing now, in the character's voice (GDD §6 "Quests"). Before Tulu has
## been heard it is the slice's only guide (CLAUDE_CODE_BRIEF.md §4.3).
static func now_line() -> String:
	var main_line := _active_quest_line(true)
	if not main_line.is_empty():
		return main_line
	if not GameState.has_flag("heard_tulu"):
		return Strings.t("now.boy_humming")
	var side_line := _active_quest_line(false)
	if not side_line.is_empty():
		return side_line
	return Strings.t("now.boy_led")


## The current objective of the first active quest, main ones or side ones.
static func _active_quest_line(main_only: bool) -> String:
	for id in Content.quest_ids():
		var quest: Quest = Content.quest(id)
		if quest.main != main_only:
			continue
		if quest.status() == Quest.Status.ACTIVE and quest.current_step_id() != "":
			return Strings.t(quest.current_objective_text_id())
	return ""


## The garden (GDD §6 "The Garden") belongs in the Grove. Until the Grove is
## built it opens here, over the pause menu (docs/DECISIONS.md).
func _open_garden() -> void:
	if _garden_overlay != null:
		return
	_garden_overlay = GARDEN_SCREEN.instantiate()
	_garden_overlay.closed.connect(_close_garden)
	add_child(_garden_overlay)


func _close_garden() -> void:
	if _garden_overlay == null:
		return
	remove_child(_garden_overlay)
	_garden_overlay.queue_free()
	_garden_overlay = null
	_garden.grab_focus()


func garden_overlay() -> Control:
	return _garden_overlay


func _refresh_map_label() -> void:
	_map.text = Strings.t("pause.map_on" if MINIMAP.enabled() else "pause.map_off")


func _on_map() -> void:
	MINIMAP.set_enabled(not MINIMAP.enabled())
	_refresh_map_label()
	map_toggled.emit(MINIMAP.enabled())
