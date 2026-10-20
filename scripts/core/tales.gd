## The tales told from the Srimad-Bhagavatam, by id, from data/tales.json.
##
## GDD §9a "Tales told": two-minute painted-scroll interludes heard when the
## player sits with someone; §3a Act 3: "Sit with Madhuri; tap to turn a
## painted scroll: Puranjana, in three sittings". A tale is a title, the
## source its card must carry (canto and chapter, §9a), a line for *Your
## journey*, and sittings, each a list of panel text ids. Every word resolves
## through the string table.
##
## Which sitting a seat offers is read off the journey's flags, and only
## flags: `heard_tale_<id>_<n>` once sitting n has been heard to its end,
## `heard_tale_<id>` once the last has. The names follow the tale id by this
## one convention (as `carrying_<item>` does), so the data stays small and
## the Garden (GDD §6: hearing waters the creeper) has one thing to read.
## Read once and cached, like Places.
class_name Tales
extends RefCounted

const PATH := "res://data/tales.json"
const FLAG_PREFIX := "heard_tale_"
## `tale.sitting.<n>`: "First sitting", "Second sitting"...
const SITTING_NAME_PREFIX := "tale.sitting."

static var _table: Dictionary = {}
static var _loaded := false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed: Variant = Strings.read_json_file(PATH)
	if not parsed is Dictionary or not parsed.get("tales") is Array:
		push_error("Tales: %s did not load" % PATH)
		return
	for entry in parsed["tales"]:
		if entry is Dictionary and entry.has("id"):
			_table[str(entry["id"])] = entry


static func ids() -> PackedStringArray:
	_load()
	var out := PackedStringArray(_table.keys())
	out.sort()
	return out


static func has(tale_id: String) -> bool:
	_load()
	return _table.has(tale_id)


static func title_id_of(tale_id: String) -> String:
	return _field(tale_id, "title_id")


static func source_id_of(tale_id: String) -> String:
	return _field(tale_id, "source_id")


static func journey_line_id_of(tale_id: String) -> String:
	return _field(tale_id, "journey_line_id")


static func review_status_of(tale_id: String) -> String:
	return _field(tale_id, "review_status")


static func sitting_count(tale_id: String) -> int:
	return _sittings(tale_id).size()


## The panel text ids of sitting [param sitting], counted from 1. Empty when
## the tale or the sitting does not exist.
static func panels(tale_id: String, sitting: int) -> PackedStringArray:
	var sittings := _sittings(tale_id)
	var out := PackedStringArray()
	if sitting < 1 or sitting > sittings.size() or not sittings[sitting - 1] is Array:
		return out
	for panel_id in sittings[sitting - 1]:
		out.append(str(panel_id))
	return out


## `heard_tale_<id>_<n>`: sitting n was heard to its end.
static func sitting_flag(tale_id: String, sitting: int) -> String:
	return "%s%s_%d" % [FLAG_PREFIX, tale_id, sitting]


## `heard_tale_<id>`: the whole tale was heard.
static func heard_flag(tale_id: String) -> String:
	return FLAG_PREFIX + tale_id


static func sitting_name_id(sitting: int) -> String:
	return "%s%d" % [SITTING_NAME_PREFIX, sitting]


## The sitting a seat offers: the first whose flag is not set, or the last
## when every one has been heard (a tale can be heard again). 0 when the tale
## is unknown or has no sittings.
static func next_sitting(tale_id: String, flags: FlagStore) -> int:
	var count := sitting_count(tale_id)
	for sitting in range(1, count + 1):
		if not flags.has(sitting_flag(tale_id, sitting)):
			return sitting
	return count


## Every flag a tale can leave, for a debug listing.
static func known_flags() -> PackedStringArray:
	var names := PackedStringArray()
	for tale_id in ids():
		for sitting in range(1, sitting_count(tale_id) + 1):
			names.append(sitting_flag(tale_id, sitting))
		names.append(heard_flag(tale_id))
	return names


static func _field(tale_id: String, key: String) -> String:
	_load()
	var entry: Variant = _table.get(tale_id)
	if entry is Dictionary:
		return str(entry.get(key, ""))
	return ""


static func _sittings(tale_id: String) -> Array:
	_load()
	var entry: Variant = _table.get(tale_id)
	if entry is Dictionary and entry.get("sittings") is Array:
		return entry["sittings"]
	return []
