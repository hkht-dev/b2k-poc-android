## The Tells of the world, by id, from data/tells.json.
##
## GDD §6 "Tells", §16a "Noticed": a Tell is a small, silent wrongness the
## player can *Look* at. Each row is {id, sentence_id, place,
## requires_humming?}: the sentence it is seen in (a string id, `tell.<id>`),
## the place it stands in (data/places.json) and whether *Look* is offered
## only while the player's hum sounds. Read once and cached, like Places.
## tools/check_data.py is to check every sentence id is in the string table
## and every place exists.
class_name Tells
extends RefCounted

const PATH := "res://data/tells.json"
const KEY := "tells"

static var _rows: Dictionary = {}
static var _order: PackedStringArray = PackedStringArray()
static var _loaded := false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed: Variant = Strings.read_json_file(PATH)
	if not parsed is Dictionary or not parsed.get(KEY) is Array:
		push_error("Tells: %s did not load" % PATH)
		return
	for row in parsed[KEY]:
		if not row is Dictionary or str(row.get("id", "")).is_empty():
			push_error("Tells: a row of %s has no id" % PATH)
			continue
		var id := str(row["id"])
		if _rows.has(id):
			push_error("Tells: two rows share the id '%s'" % id)
			continue
		_rows[id] = row
		_order.append(id)


## Every tell id, in file order.
static func ids() -> PackedStringArray:
	_load()
	return _order.duplicate()


static func has(tell_id: String) -> bool:
	_load()
	return _rows.has(tell_id)


## The string id of the sentence the tell is seen in, or "" if unknown.
static func sentence_id_of(tell_id: String) -> String:
	_load()
	var row: Variant = _rows.get(tell_id)
	return str(row.get("sentence_id", "")) if row is Dictionary else ""


## The place the tell stands in (data/places.json), or "" if unknown.
static func place_of(tell_id: String) -> String:
	_load()
	var row: Variant = _rows.get(tell_id)
	return str(row.get("place", "")) if row is Dictionary else ""


## Whether *Look* is offered only while the player's hum sounds.
static func requires_humming(tell_id: String) -> bool:
	_load()
	var row: Variant = _rows.get(tell_id)
	return row is Dictionary and bool(row.get("requires_humming", false))


## The ids of the tells in a place, in file order.
static func in_place(place_id: String) -> PackedStringArray:
	_load()
	var out := PackedStringArray()
	for id in _order:
		if place_of(id) == place_id:
			out.append(id)
	return out
