## The Garden: the game's picture of karma and bhakti, kept on the journey
## and derived from it.
##
## GDD §6 "The Garden: seeds, fruit and the creeper": every choice drops a
## seed into the plot with the sentence it came from; saplings grow over
## real days; a repeated kind of choice is a thicker trunk; weeds are pulled
## by hand; the creeper's seed is given, watered by hearing, chanting,
## remembering and service, and shades the saplings as it climbs. GDD §16a
## "Days and lives": garden time passes only on play-days, so absence costs
## nothing; a play-day is the first play on a new calendar date.
##
## Which sources plant which seeds, which flags water, and how many days a
## seed takes are data in data/garden.json. The state lives in
## `GameState.garden` (one Dictionary, saved with the rest). No number here
## is ever shown: the screen draws stems and dots, and the only text a plant
## has is its sentence (GDD §6 "Rules").
class_name Garden
extends RefCounted

const DATA_PATH := "res://data/garden.json"
const KINDS := ["sweet", "bitter", "weed"]
const KIND_WEED := "weed"
const FLAG_SOURCE := "flag:"
const CHOICE_SOURCE := "choice:"
## A repeated choice plants again. The second record carries this mark and
## an ordinal after its source, so every seed has its own id to pull by.
const REPEAT_MARK := "#"

const STAGE_SEED := "seed"
const STAGE_SAPLING := "sapling"
const STAGE_FRUITING := "fruiting"
const STAGE_SHADED := "shaded"
const STAGE_WEED := "weed"
const STAGE_PULLED := "pulled"

static var _data: Dictionary = {}

# -- the dictionary on the journey ------------------------------------------


static func empty() -> Dictionary:
	return {
		"seeds": [],
		"pulled": [],
		"creeper": {"given": false, "watered_days": []},
		"days": 0,
		"last_date": "",
	}


## A saved garden made whole: anything missing gets its empty value, so a
## journey saved before the garden existed loads with a bare plot and JSON's
## floats come back as the ints they were.
static func normalised(value: Variant) -> Dictionary:
	var out := empty()
	if not value is Dictionary:
		return out
	var seeds: Array = []
	for seed in value.get("seeds", []):
		if seed is Dictionary and seed.has("id") and seed.has("kind"):
			(
				seeds
				. append(
					{
						"id": str(seed["id"]),
						"kind": str(seed["kind"]),
						"day_planted": int(seed.get("day_planted", 0)),
					}
				)
			)
	out["seeds"] = seeds
	out["pulled"] = _strings(value.get("pulled", []))
	var creeper: Variant = value.get("creeper", {})
	if creeper is Dictionary:
		out["creeper"]["given"] = bool(creeper.get("given", false))
		out["creeper"]["watered_days"] = _ints(creeper.get("watered_days", []))
	out["days"] = int(value.get("days", 0))
	out["last_date"] = str(value.get("last_date", ""))
	return out


# -- data ---------------------------------------------------------------------


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = Strings.read_json_file(DATA_PATH)
		if parsed is Dictionary:
			_data = parsed
		else:
			push_error("Garden: no usable data at %s" % DATA_PATH)
			_data = {"seeds": [], "creeper": {}, "waters": {}, "growth": {}}
	return _data


## The creeper's section of the data: given_flag, sentence_id, shade_steps.
static func creeper_data() -> Dictionary:
	var section: Variant = data().get("creeper", {})
	return section if section is Dictionary else {}


# -- days ---------------------------------------------------------------------


## Play-days so far; today's index. Never shown.
static func days(state: Node) -> int:
	return int(state.garden.get("days", 0))


## Begins a play-day if the calendar date changed since the last play
## (GDD §16a: a session is a day; the clock between plays counts for
## nothing). [param today] is for tests; the game passes nothing and reads
## the system date. Returns true when a new day began. Either way the plot is
## brought up to date with what the journey already holds.
static func advance_day(state: Node, today: String = "") -> bool:
	var date := today if not today.is_empty() else Time.get_date_string_from_system()
	var garden: Dictionary = state.garden
	var last := str(garden.get("last_date", ""))
	var advanced := false
	if last != date:
		if not last.is_empty():
			garden["days"] = days(state) + 1
			advanced = true
		garden["last_date"] = date
		state.garden_changed()
	reconcile(state)
	return advanced


## Plants whatever the journey holds that the plot does not yet: a flag set
## before the garden existed, a choice made while it was not watching. They
## are planted as of today, the day they were noticed. Also notices the
## creeper's seed being given.
static func reconcile(state: Node) -> void:
	var given_flag := str(creeper_data().get("given_flag", ""))
	if not given_flag.is_empty() and state.has_flag(given_flag) and not creeper_given(state):
		state.garden["creeper"]["given"] = true
		state.garden_changed()
	for entry in data().get("seeds", []):
		if not entry is Dictionary:
			continue
		var source := str(entry.get("source", ""))
		var wanted := _occurrences(state, source)
		var have := _records_for(state, source)
		while have < wanted:
			_plant(state, source, str(entry.get("kind", "")))
			have += 1


## GameState calls this when a flag is set: the flag may plant, may give the
## creeper its seed, may water it.
static func on_flag(state: Node, flag: String) -> void:
	reconcile(state)
	var waters: Variant = data().get("waters", {})
	var flags: Array = waters.get("flags", []) if waters is Dictionary else []
	if flags.has(flag):
		water(state)


# -- the creeper --------------------------------------------------------------


## Today waters the creeper, if its seed has been given. Returns true when
## today was not yet watered; a day is watered once however often it rains.
static func water(state: Node) -> bool:
	if not creeper_given(state):
		return false
	var watered: Array = state.garden["creeper"]["watered_days"]
	var today := days(state)
	if watered.has(today):
		return false
	watered.append(today)
	state.garden_changed()
	return true


static func creeper_given(state: Node) -> bool:
	return bool(state.garden["creeper"].get("given", false))


## How far the creeper has climbed: one step per watered play-day. Drawn,
## never written.
static func creeper_steps(state: Node) -> int:
	return state.garden["creeper"]["watered_days"].size()


## The creeper has climbed far enough to shade the saplings (GDD §6: "as it
## rises it shades the saplings, which stop fruiting").
static func is_shading(state: Node) -> bool:
	return creeper_steps(state) >= int(creeper_data().get("shade_steps", 3))


# -- the plot -----------------------------------------------------------------


## Every seed ever planted, in planting order, with its kind, its stage
## today, the id of its sentence and how thick its kind has grown (how many
## living seeds share it: "a habit is a thicker trunk").
static func plot(state: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var counts := _living_counts(state)
	for seed in state.garden["seeds"]:
		var entry := _entry_for(seed["id"])
		(
			out
			. append(
				{
					"id": seed["id"],
					"kind": seed["kind"],
					"stage": _stage(state, seed),
					"sentence_id": str(entry.get("sentence_id", "")),
					"thickness": int(counts.get(seed["kind"], 0)),
					"day_planted": int(seed["day_planted"]),
				}
			)
		)
	return out


static func is_pulled(state: Node, id: String) -> bool:
	return state.garden["pulled"].has(id)


## Pulls a weed by hand. Only a weed, only once; the record stays so the
## scar is visible and the seed is not planted again (GDD §6 "Regrowth").
static func pull(state: Node, id: String) -> bool:
	for seed in state.garden["seeds"]:
		if seed["id"] == id and seed["kind"] == KIND_WEED and not is_pulled(state, id):
			state.garden["pulled"].append(id)
			state.garden_changed()
			return true
	return false


## The weeds still standing.
static func weeds(state: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for plant in plot(state):
		if plant["stage"] == STAGE_WEED:
			out.append(plant)
	return out


## Saplings that are fruiting today. The vignettes that taste them are
## another feature's (GDD §6 "Fruit").
static func ripe_fruit(state: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for plant in plot(state):
		if plant["stage"] == STAGE_FRUITING:
			out.append(plant)
	return out


# -- private ------------------------------------------------------------------


static func _stage(state: Node, seed: Dictionary) -> String:
	if is_pulled(state, seed["id"]):
		return STAGE_PULLED
	if seed["kind"] == KIND_WEED:
		return STAGE_WEED
	var growth: Variant = data().get("growth", {})
	var sapling_after := int(growth.get("sapling_after_days", 1)) if growth is Dictionary else 1
	var fruiting_after := int(growth.get("fruiting_after_days", 2)) if growth is Dictionary else 2
	var age := days(state) - int(seed["day_planted"])
	if age < sapling_after:
		return STAGE_SEED
	if age < fruiting_after:
		return STAGE_SAPLING
	return STAGE_SHADED if is_shading(state) else STAGE_FRUITING


static func _plant(state: Node, source: String, kind: String) -> void:
	if not KINDS.has(kind):
		push_error("Garden: '%s' plants an unknown kind '%s'" % [source, kind])
		return
	var before := _records_for(state, source)
	var id := source if before == 0 else "%s%s%d" % [source, REPEAT_MARK, before + 1]
	state.garden["seeds"].append({"id": id, "kind": kind, "day_planted": days(state)})
	state.garden_changed()


## How many times the journey holds a source: a flag once if set, a choice
## as often as it was made.
static func _occurrences(state: Node, source: String) -> int:
	if source.begins_with(FLAG_SOURCE):
		return 1 if state.has_flag(source.trim_prefix(FLAG_SOURCE)) else 0
	if source.begins_with(CHOICE_SOURCE):
		var parts := source.trim_prefix(CHOICE_SOURCE).rsplit(":", true, 1)
		if parts.size() != 2:
			return 0
		var count := 0
		for entry in state.choice_history:
			if (
				str(entry.get("line", "")) == parts[0]
				and int(entry.get("card", -1)) == int(parts[1])
			):
				count += 1
		return count
	return 0


static func _records_for(state: Node, source: String) -> int:
	var count := 0
	for seed in state.garden["seeds"]:
		if _source_of(seed["id"]) == source:
			count += 1
	return count


static func _source_of(id: String) -> String:
	return id.split(REPEAT_MARK)[0]


static func _entry_for(id: String) -> Dictionary:
	var source := _source_of(id)
	for entry in data().get("seeds", []):
		if entry is Dictionary and str(entry.get("source", "")) == source:
			return entry
	return {}


## Living seeds per kind: thickness is shared by every stem of a habit.
static func _living_counts(state: Node) -> Dictionary:
	var counts: Dictionary = {}
	for seed in state.garden["seeds"]:
		if not is_pulled(state, seed["id"]):
			counts[seed["kind"]] = int(counts.get(seed["kind"], 0)) + 1
	return counts


static func _strings(value: Variant) -> Array:
	var out: Array = []
	if value is Array:
		for item in value:
			out.append(str(item))
	return out


static func _ints(value: Variant) -> Array:
	var out: Array = []
	if value is Array:
		for item in value:
			out.append(int(item))
	return out


## Every flag the garden's data reads: seed sources, the creeper's seed and
## the waters, for the debug panel (Content.known_flags).
static func known_flags() -> PackedStringArray:
	var names := PackedStringArray()
	for seed in data().get("seeds", []):
		var source := str(seed.get("source", "")) if seed is Dictionary else ""
		if source.begins_with("flag:"):
			names.append(source.trim_prefix("flag:"))
	var given_flag := str(creeper_data().get("given_flag", ""))
	if not given_flag.is_empty():
		names.append(given_flag)
	var waters: Variant = data().get("waters", {})
	if waters is Dictionary:
		for flag in waters.get("flags", []):
			names.append(str(flag))
	return names
