## The lamps' data, from data/lamp_lines.json: the twelve preset lines, how
## many lamps a place holds, and how long a lamp burns.
##
## GDD §16a "Social: lamps": "one of twelve preset lines ... lamps fade after
## thirty days". Every line is a string id (the text is in the string table),
## so no lamp ever carries free text. A "day" here is a play-day (GDD §16a
## "Days and lives": about fifteen minutes of play), counted from the
## journey's play_seconds; nothing shows it, and nothing counts down. Read
## once and cached, like scripts/core/places.gd.
class_name LampLines
extends RefCounted

const PATH := "res://data/lamp_lines.json"
## Used only if the file does not say otherwise.
const DEFAULT_DAYS := 30
const DEFAULT_MAX_PER_PLACE := 8
const DEFAULT_SECONDS_PER_DAY := 900.0

static var _table: Dictionary = {}
static var _loaded := false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed: Variant = Strings.read_json_file(PATH)
	if parsed is Dictionary:
		_table = parsed
	else:
		push_error("LampLines: %s did not load" % PATH)


## The preset line ids, in the order the data lists them.
static func line_ids() -> PackedStringArray:
	_load()
	return _ids(_table.get("lines", []))


static func has_line(line_id: String) -> bool:
	return line_ids().has(line_id)


## Play-days a lamp burns before it fades.
static func fade_days() -> int:
	_load()
	return int(_table.get("days", DEFAULT_DAYS))


## Lamps one place holds; the oldest goes out when another is set.
static func max_per_place() -> int:
	_load()
	return int(_table.get("max_per_place", DEFAULT_MAX_PER_PLACE))


static func seconds_per_day() -> float:
	_load()
	return float(_table.get("seconds_per_day", DEFAULT_SECONDS_PER_DAY))


## The journey's current play-day: whole days of play so far.
static func play_day() -> int:
	return int(floor(GameState.play_seconds / maxf(1.0, seconds_per_day())))


## Whether a lamp record {place, x, z, line_id, lit_day} still burns.
static func is_lit(lamp: Dictionary) -> bool:
	return play_day() - int(lamp.get("lit_day", 0)) < fade_days()


static func _ids(value: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if value is Array:
		for item in value:
			out.append(str(item))
	return out
