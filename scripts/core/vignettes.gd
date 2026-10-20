## The dawn vignettes: one new short encounter in the Street each real day,
## from a rotating pool that ships in the build.
##
## GDD §16a "Dawn vignettes": "Every real day, the Street has one new 2–4
## minute encounter from a rotating pool ... Missed days queue; nothing is
## lost." The pick is by the calendar date, never a timer: the same date gives
## the same vignette on every device, and consecutive days walk the pool in
## order. The journey remembers which dates it has been granted
## (GameState.vignette_days); what is granted but not yet played waits,
## oldest first. A played vignette has the flag `vignette_<id>_done`, which is
## what takes it out of the queue, and its journey line.
##
## The pool is data/vignettes/<id>.json. Each file carries its stranger (a
## name id, a skin, one of three fixed spots on the street), its own dialogue
## lines in the shape of data/dialogue/en.json, the flags its cards set
## (`outcomes`) and one journey line. Read once and cached, like Places. No
## backend: GDD §16a's delivery is a folder in the build.
class_name Vignettes
extends RefCounted

const DIR := "res://data/vignettes/"
const REQUIRED := ["id", "giver_name_id", "skin", "spot", "lines", "journey_line_id", "outcomes"]
const SPOTS := ["a", "b", "c"]
const DONE_SUFFIX := "_done"
const SECONDS_PER_DAY := 86400

## The pool, sorted by id so the date index is stable.
static var _pool: Array[Dictionary] = []
static var _by_id: Dictionary = {}
static var _loaded := false

# -- the pool -----------------------------------------------------------------


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_pool.clear()
	_by_id.clear()
	var dir := DirAccess.open(DIR)
	if dir == null:
		push_error("Vignettes: cannot open %s" % DIR)
		return
	var names := Array(dir.get_files())
	names.sort()
	for file_name in names:
		if not str(file_name).ends_with(".json"):
			continue
		var path := DIR + str(file_name)
		var parsed: Variant = Strings.read_json_file(path)
		if not parsed is Dictionary:
			continue
		var vignette := _vignette(parsed, path)
		if vignette.is_empty():
			continue
		if _by_id.has(vignette["id"]):
			push_error("Vignettes: two vignettes share the id '%s'" % vignette["id"])
			continue
		_by_id[vignette["id"]] = vignette
	var ids := Array(_by_id.keys())
	ids.sort()
	for id in ids:
		_pool.append(_by_id[id])


## Forgets the cache so the next call reads the folder again (tests).
static func reload() -> void:
	_loaded = false
	_load()


static func all() -> Array[Dictionary]:
	_load()
	return _pool


static func size() -> int:
	_load()
	return _pool.size()


static func ids() -> PackedStringArray:
	_load()
	var out := PackedStringArray()
	for vignette in _pool:
		out.append(vignette["id"])
	return out


static func has(id: String) -> bool:
	_load()
	return _by_id.has(id)


static func get_vignette(id: String) -> Dictionary:
	_load()
	return _by_id.get(id, {})


## The line *Talk* opens: the first line in the vignette's table.
static func entry_line_id(vignette: Dictionary) -> String:
	var lines: Dictionary = vignette.get("lines", {})
	if lines.is_empty():
		return ""
	return str(lines.keys()[0])


static func done_flag(id: String) -> String:
	return "vignette_%s%s" % [id, DONE_SUFFIX]


# -- the calendar -------------------------------------------------------------


## Today, as the device's calendar says ("YYYY-MM-DD").
static func today() -> String:
	return Time.get_date_string_from_system()


## Days since 1970-01-01 for a "YYYY-MM-DD" string.
static func day_number(date: String) -> int:
	return int(Time.get_unix_time_from_datetime_string(date + "T00:00:00") / SECONDS_PER_DAY)


static func date_of_day(day: int) -> String:
	return Time.get_date_string_from_unix_time(day * SECONDS_PER_DAY)


## The vignette a date gives, the same on every device: a stable index into
## the pool by the day count, so consecutive days walk the pool in order.
static func id_for_date(date: String) -> String:
	_load()
	if _pool.is_empty():
		return ""
	return _pool[posmod(day_number(date), _pool.size())]["id"]


static func today_id() -> String:
	return id_for_date(today())


# -- the queue ----------------------------------------------------------------


## Grants today's vignette, and every missed day's since the last grant, to
## the journey. A journey that has never been granted one gets today only.
## The backfill reaches at most one pool's worth of days: older missed days
## would only repeat vignettes already in the queue. Returns the dates newly
## granted, oldest first.
static func grant_today(state: Node = null, date: String = "") -> PackedStringArray:
	_load()
	var journey := _state(state)
	var today_date := date if not date.is_empty() else today()
	var today_day := day_number(today_date)
	var last := -1
	for granted in journey.vignette_days:
		last = maxi(last, day_number(granted))
	var first := today_day
	if last >= 0 and last < today_day:
		first = maxi(last + 1, today_day - maxi(_pool.size(), 1) + 1)
	var added := PackedStringArray()
	for day in range(first, today_day + 1):
		var day_date := date_of_day(day)
		if journey.grant_vignette_day(day_date):
			added.append(day_date)
	return added


## Granted and not yet played, oldest day first, each vignette once.
static func pending(state: Node = null) -> Array[Dictionary]:
	_load()
	var journey := _state(state)
	var days: Array[int] = []
	for granted in journey.vignette_days:
		days.append(day_number(granted))
	days.sort()
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	for day in days:
		var id := id_for_date(date_of_day(day))
		if id.is_empty() or seen.has(id) or is_done(id, journey):
			continue
		seen[id] = true
		out.append(_by_id[id])
	return out


## The oldest pending vignette that stands at [param spot], or {}.
static func pending_for_spot(spot: String, state: Node = null) -> Dictionary:
	for vignette in pending(state):
		if vignette["spot"] == spot:
			return vignette
	return {}


static func is_done(id: String, state: Node = null) -> bool:
	return _state(state).has_flag(done_flag(id))


## A card set one of the vignette's outcomes: the vignette is played. Writes
## the done flag and the journey line. Returns false if it was already done.
static func complete(id: String, state: Node = null) -> bool:
	var vignette := get_vignette(id)
	if vignette.is_empty() or is_done(id, state):
		return false
	var journey := _state(state)
	journey.add_journey_line(vignette["journey_line_id"])
	journey.set_flag(done_flag(id))
	return true


## Every flag the pool reads or sets, for the debug panel's listing.
static func known_flags() -> PackedStringArray:
	_load()
	var names := PackedStringArray()
	for vignette in _pool:
		names.append(done_flag(vignette["id"]))
		names.append_array(vignette["outcomes"])
	return names


# -- parsing ------------------------------------------------------------------


static func _state(state: Node) -> Node:
	return state if state != null else GameState


static func _vignette(raw: Dictionary, source: String) -> Dictionary:
	for key in REQUIRED:
		if not raw.has(key):
			push_error("Vignettes %s: missing '%s'" % [source, key])
			return {}
	var id := str(raw["id"])
	if not SPOTS.has(str(raw["spot"])):
		push_error("Vignettes %s: spot '%s' is not one of a, b, c" % [source, raw["spot"]])
		return {}
	if not raw["lines"] is Dictionary or (raw["lines"] as Dictionary).is_empty():
		push_error("Vignettes %s: 'lines' must be a table with a first line" % source)
		return {}
	var outcomes := PackedStringArray()
	if raw["outcomes"] is Array:
		for flag in raw["outcomes"]:
			outcomes.append(str(flag))
	# The lines must parse as dialogue; a vignette that would fail at the
	# spot is refused here, once, by name.
	if Dialogue.from_dict(raw["lines"], source) == null:
		return {}
	return {
		"id": id,
		"giver_name_id": str(raw["giver_name_id"]),
		"skin": str(raw["skin"]),
		"spot": str(raw["spot"]),
		"lines": raw["lines"],
		"journey_line_id": str(raw["journey_line_id"]),
		"outcomes": outcomes,
	}
