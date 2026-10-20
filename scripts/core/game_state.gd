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
signal outfit_changed(outfit_id: String)
## A lamp was set down (GDD §16a); the place it is in shows it.
signal lamp_set(lamp: Dictionary)
signal noticed_added(tell_id: String)
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
## The Tells the player has looked at (GDD §6 "Tells", §16a "Noticed"):
## tell ids from data/tells.json, in the order seen. Never counted, never a
## number anywhere; *Your journey* lists their sentences.
var noticed: Array[String] = []
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
## Real days ("YYYY-MM-DD") whose dawn vignette the journey has been granted
## (GDD §16a "Dawn vignettes": missed days queue, nothing is lost). Which of
## them has been played is a flag, `vignette_<id>_done`, like everything else.
var vignette_days: Array[String] = []
## The garden (GDD §6 "The Garden"): seeds with the day they were planted,
## what was pulled, the creeper's watered days, the count of play-days and
## the last date played. Kept by scripts/core/garden.gd; shown only on its
## own screen, never as a number.
var garden: Dictionary = Garden.empty()
## What the player wears: an outfit id from data/outfits.json, or "" for
## the skin the player scene carries. Owner request 2026-10-20 (the
## showroom's wardrobe); cosmetic, Street-only, and the body listens.
var outfit: String = ""
## Lamps the player has set down (GDD §16a "Social: lamps"), oldest first:
## each {place, x, z, line_id, lit_day}. Owner expansion 2026-10-20. In this
## build they are the player's own; other people's lamps need the backend
## the slice does not have (docs/DECISIONS.md).
var lamps: Array[Dictionary] = []
## Where the one slot lives. Tests point this at a scratch file.
var save_path: String = SAVE_PATH

var _autosave := true


func _init() -> void:
	# Wired here, not in _ready, so a bare instance in a test still emits.
	flags.changed.connect(_on_flag_changed)


func _ready() -> void:
	load_journey()
	# The first play on a new calendar date is a play-day (GDD §16a).
	Garden.advance_day(self)


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


## The player put something else on (the showroom's wardrobe). The body
## listens for the signal; the journey file keeps the id.
func set_outfit(outfit_id: String) -> void:
	if outfit_id == outfit:
		return
	outfit = outfit_id
	outfit_changed.emit(outfit)
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
	Garden.reconcile(self)
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


## Records that a real day's dawn vignette has been granted (GDD §16a).
## Returns false if that day already was.
func grant_vignette_day(date: String) -> bool:
	if date.is_empty() or vignette_days.has(date):
		return false
	vignette_days.append(date)
	_save_if_enabled()
	return true


## Records that the player looked at a Tell. Returns false if it was already
## noticed: the list holds each once, and nothing counts them (GDD §6).
func notice(tell_id: String) -> bool:
	if tell_id.is_empty() or noticed.has(tell_id):
		return false
	noticed.append(tell_id)
	noticed_added.emit(tell_id)
	_save_if_enabled()
	return true


# -- lamps --------------------------------------------------------------------


## Sets a lamp down: {place, x, z, line_id, lit_day}. A place holds at most
## `max_per_place` lamps; past that, the oldest one there goes out. Returns
## the lamp that went out, or an empty Dictionary.
func set_lamp(lamp: Dictionary, max_per_place: int) -> Dictionary:
	lamps.append(lamp)
	var place_id := str(lamp.get("place", ""))
	var gone := {}
	while max_per_place > 0 and lamps_in(place_id).size() > max_per_place:
		var popped: Variant = lamps.pop_at(_oldest_lamp_index(place_id))
		if popped is Dictionary:
			gone = popped
	lamp_set.emit(lamp)
	_save_if_enabled()
	return gone


## The lamps set in one place, oldest first.
func lamps_in(place_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for lamp in lamps:
		if str(lamp.get("place", "")) == place_id:
			out.append(lamp)
	return out


func _oldest_lamp_index(place_id: String) -> int:
	for index in lamps.size():
		if str(lamps[index].get("place", "")) == place_id:
			return index
	return -1


# -- persistence --------------------------------------------------------------


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"beat": beat,
		"flags": Array(flags.all()),
		"events": Array(events.all()),
		"choice_history": choice_history.duplicate(true),
		"journey_lines": journey_lines.duplicate(),
		"noticed": noticed.duplicate(),
		"settings": settings.duplicate(true),
		"hum_count": hum_count,
		"play_seconds": play_seconds,
		"place": place,
		"spawn": spawn,
		"vignette_days": vignette_days.duplicate(),
		"garden": garden.duplicate(true),
		"outfit": outfit,
		"lamps": lamps.duplicate(true),
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
	noticed.clear()
	for tell_id in _string_array(data.get("noticed", [])):
		noticed.append(tell_id)
	settings = data.get("settings", {}) if data.get("settings") is Dictionary else {}
	hum_count = int(data.get("hum_count", 0))
	play_seconds = float(data.get("play_seconds", 0.0))
	place = str(data.get("place", DEFAULT_PLACE))
	if place.is_empty():
		place = DEFAULT_PLACE
	spawn = str(data.get("spawn", ""))
	vignette_days.clear()
	for date in _string_array(data.get("vignette_days", [])):
		vignette_days.append(date)
	garden = Garden.normalised(data.get("garden"))
	outfit = str(data.get("outfit", ""))
	lamps.clear()
	for lamp in data.get("lamps", []):
		if lamp is Dictionary:
			lamps.append(lamp)


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
	noticed.clear()
	settings = {}
	hum_count = 0
	play_seconds = 0.0
	place = DEFAULT_PLACE
	spawn = ""
	vignette_days.clear()
	garden = Garden.empty()
	outfit = ""
	lamps.clear()
	_autosave = true
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	wiped.emit()


## Tests turn this off so they never touch the real journey file.
func set_autosave(enabled: bool) -> void:
	_autosave = enabled


## The garden changed outside a flag or a choice (a day began, a weed was
## pulled, the creeper was watered): save, if saving is on.
func garden_changed() -> void:
	_save_if_enabled()


func _on_flag_changed(flag: String, is_set: bool) -> void:
	if is_set:
		Garden.on_flag(self, flag)
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
