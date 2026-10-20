## The places of the world, by id, from data/places.json.
##
## A place id names a scene and a name string; the journey remembers the id
## (GameState.place), never a scene path, so scenes can move. Read once and
## cached. tools/check_data.py checks every entry's scene exists and its
## name id is in the string table.
class_name Places
extends RefCounted

const PATH := "res://data/places.json"
const DEFAULT_PLACE := "street"

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
		push_error("Places: %s did not load" % PATH)


static func ids() -> PackedStringArray:
	_load()
	var out := PackedStringArray(_table.keys())
	out.sort()
	return out


static func has(place_id: String) -> bool:
	_load()
	return _table.has(place_id)


## The scene path for a place id, or "" if the id is unknown.
static func scene_of(place_id: String) -> String:
	_load()
	var entry: Variant = _table.get(place_id)
	if entry is Dictionary:
		return str(entry.get("scene", ""))
	return ""


static func name_id_of(place_id: String) -> String:
	_load()
	var entry: Variant = _table.get(place_id)
	if entry is Dictionary:
		return str(entry.get("name_id", ""))
	return ""
