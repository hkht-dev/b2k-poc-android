## The one object that is the player's journey: beat, flags, events, choices,
## journey lines and settings. Saved whole, loaded whole, wiped whole.
##
## GDD §12 "Game state": "A single serializable JourneyState ... One object to
## save, one to inspect, one to reset." CLAUDE_CODE_BRIEF.md §5: autosave on
## every flag change and beat change to user://journey.json, one slot, and
## *Play again* wipes it.
##
## Registered as the autoload `GameState`.
extends Node

signal flag_changed(flag: String, is_set: bool)
signal event_fired(event: String)
signal beat_changed(beat: String)
signal journey_line_added(line_id: String)
signal wiped

const SAVE_PATH := "user://journey.json"
const SAVE_VERSION := 1
const HUMMED_FLAG := "hummed"
const HUMMED_AT := 3
const DEFAULT_PLACE := "street"

## Beats are an ordered list of ids in data (GDD §12). The slice has one.
var beat: String = ""
var flags := FlagStore.new()
## World events that have happened: a can placed, a feather picked up. Kept
## apart from flags because a quest step waits on what the world did, and a
## card sets what the player chose; the debug panel shows them separately.
var events := FlagStore.new()
var choice_history: Array[Dictionary] = []
var journey_lines: Array[String] = []
## Wisdom cards whose lotus has been offered this journey, by id (GDD §6
## "Optional wisdom": once per card; ignoring it has no effect, so what is
## kept is that it was offered, not whether it was opened).
var wisdom_seen: Array[String] = []
var settings: Dictionary = {}
## Times the player has hummed (CLAUDE_CODE_BRIEF.md §4.2 "Track hummed
## count"). The flag `hummed` is set at three (GDD §6 "Remembering Krishna").
var hum_count: int = 0
## Seconds played in this journey (CLAUDE_CODE_BRIEF.md §4.6: the bus stop's
## *Sit* opens after 90 s of play). Counted by the street, saved with the
## rest; not a timer the player sees.
var play_seconds: float = 0.0
## Where the player is: a place id from data/places.json, and the spawn
## point they last arrived on there (empty: where the scene puts them).
## Owner expansion 2026-10-20: the world has doors, so the journey remembers
## which side of one the player is on.
var place: String = DEFAULT_PLACE
var spawn: String = ""
## Where the one slot lives. Tests point this at a scratch file.
var save_path: String = SAVE_PATH

var _autosave := true


func _init() -> void:
	# Wired here, not in _ready, so a bare instance in a test still emits.
	flags.changed.connect(_on_flag_changed)


func _ready() -> void:
	load_journey()


# -- flags --------------------------------------------------------------------


func set_flag(flag: String) -> bool:
	return flags.set_flag(flag)


func clear_flag(flag: String) -> bool:
	return flags.clear_flag(flag)


func has_flag(flag: String) -> bool:
	return flags.has(flag)


# -- events -------------------------------------------------------------------


## Records that something happened in the world. Returns false if it had
## already happened; an event fires once.
func fire_event(event: String) -> bool:
	if not events.set_flag(event):
		return false
	event_fired.emit(event)
	_save_if_enabled()
	return true


func has_event(event: String) -> bool:
	return events.has(event)


# -- beat, choices, journey ---------------------------------------------------


## Counts a hum; the third sets `hummed`.
## Adds played time. Not autosaved on its own: the next flag or event
## carries it.
func add_play_time(delta: float) -> void:
	play_seconds += maxf(0.0, delta)


func record_hum() -> int:
	hum_count += 1
	if hum_count >= HUMMED_AT:
		set_flag(HUMMED_FLAG)
	_save_if_enabled()
	return hum_count


## The player is going through a door: where to, and which spawn point.
func set_place(place_id: String, spawn_id: String) -> void:
	place = place_id
	spawn = spawn_id
	_save_if_enabled()


func set_beat(new_beat: String) -> void:
	if new_beat == beat:
		return
	beat = new_beat
	beat_changed.emit(beat)
	_save_if_enabled()


## Records a card the player chose. Kept as ids, never text, so the record is
## stable across locales and rewrites.
func record_choice(line_id: String, card_index: int, sets: PackedStringArray) -> void:
	choice_history.append({"line": line_id, "card": card_index, "sets": Array(sets)})
	_save_if_enabled()


## Adds a line to *Your journey* (GDD §6 "Choice"). Duplicates are ignored so
## a quest that ends twice on reload does not say so twice.
func add_journey_line(line_id: String) -> bool:
	if line_id.is_empty() or journey_lines.has(line_id):
		return false
	journey_lines.append(line_id)
	journey_line_added.emit(line_id)
	_save_if_enabled()
	return true


## Records that a wisdom card's lotus was offered. Returns false if it had
## been already: a card is offered once per journey (GDD §9).
func mark_wisdom_seen(card_id: String) -> bool:
	if card_id.is_empty() or wisdom_seen.has(card_id):
		return false
	wisdom_seen.append(card_id)
	_save_if_enabled()
	return true


func has_seen_wisdom(card_id: String) -> bool:
	return wisdom_seen.has(card_id)


# -- persistence --------------------------------------------------------------


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"beat": beat,
		"flags": Array(flags.all()),
		"events": Array(events.all()),
		"choice_history": choice_history.duplicate(true),
		"journey_lines": journey_lines.duplicate(),
		"wisdom_seen": wisdom_seen.duplicate(),
		"settings": settings.duplicate(true),
		"hum_count": hum_count,
		"play_seconds": play_seconds,
		"place": place,
		"spawn": spawn,
	}


## Replaces the whole state from a saved dictionary. Emits nothing per flag:
## loading is restoring what already was, not a change.
func from_dict(data: Dictionary) -> void:
	beat = str(data.get("beat", ""))
	flags.replace_all(_string_array(data.get("flags", [])))
	events.replace_all(_string_array(data.get("events", [])))
	choice_history.clear()
	for entry in data.get("choice_history", []):
		if entry is Dictionary:
			choice_history.append(entry)
	journey_lines.clear()
	for line in _string_array(data.get("journey_lines", [])):
		journey_lines.append(line)
	wisdom_seen.clear()
	for card_id in _string_array(data.get("wisdom_seen", [])):
		wisdom_seen.append(card_id)
	settings = data.get("settings", {}) if data.get("settings") is Dictionary else {}
	hum_count = int(data.get("hum_count", 0))
	play_seconds = float(data.get("play_seconds", 0.0))
	place = str(data.get("place", DEFAULT_PLACE))
	if place.is_empty():
		place = DEFAULT_PLACE
	spawn = str(data.get("spawn", ""))


func save() -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("GameState: cannot write %s (%s)" % [save_path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(to_dict(), "  "))
	return true


## Loads the one slot if it exists. A missing file is a new journey, not an
## error; a corrupt one is reported and ignored rather than crashing the title.
func load_journey() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var parsed: Variant = Strings.read_json_file(save_path)
	if not parsed is Dictionary:
		push_error("GameState: %s is not a journey file; starting fresh" % save_path)
		return false
	_autosave = false
	from_dict(parsed)
	_autosave = true
	return true


## *Play again*: wipes everything and the file behind it.
func wipe() -> void:
	_autosave = false
	beat = ""
	flags.clear_all()
	events.clear_all()
	choice_history.clear()
	journey_lines.clear()
	wisdom_seen.clear()
	settings = {}
	hum_count = 0
	play_seconds = 0.0
	place = DEFAULT_PLACE
	spawn = ""
	_autosave = true
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	wiped.emit()


## Tests turn this off so they never touch the real journey file.
func set_autosave(enabled: bool) -> void:
	_autosave = enabled


func _on_flag_changed(flag: String, is_set: bool) -> void:
	flag_changed.emit(flag, is_set)
	_save_if_enabled()


func _save_if_enabled() -> void:
	if _autosave:
		save()


static func _string_array(value: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if value is Array:
		for item in value:
			out.append(str(item))
	return out
