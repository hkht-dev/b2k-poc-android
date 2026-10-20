## The optional wisdom cards, by id, from data/wisdom.json.
##
## GDD §6 "Optional wisdom" and §9 "Wisdom encounters": seven cards, each
## tied to a beat the player has just lived through. A card is a row of
## data: its trigger is a condition over flags (scripts/lib/condition.gd),
## and its verse, meaning, note and source are string ids. Read once and
## cached; a row that will not parse is reported by id and skipped, never a
## crash. tools/check_data.py should mirror these checks.
class_name Wisdom
extends RefCounted

const PATH := "res://data/wisdom.json"
const REQUIRED := ["id", "trigger", "verse_id", "meaning_id", "more_id", "source_id"]
const STRING_FIELDS := ["verse_id", "meaning_id", "more_id", "source_id"]

static var _cards: Dictionary = {}
static var _order: PackedStringArray = PackedStringArray()
static var _loaded := false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed: Variant = Strings.read_json_file(PATH)
	if not parsed is Dictionary or not parsed.get("cards") is Array:
		push_error("Wisdom: %s did not load or has no 'cards' list" % PATH)
		return
	for raw in parsed["cards"]:
		var row := _card_from(raw)
		if row.is_empty():
			continue
		var id: String = row["id"]
		if _cards.has(id):
			push_error("Wisdom: two cards share the id '%s'" % id)
			continue
		_cards[id] = row
		_order.append(id)


static func _card_from(raw: Variant) -> Dictionary:
	if not raw is Dictionary:
		push_error("Wisdom: a card is not an object")
		return {}
	for key in REQUIRED:
		if not raw.has(key) or str(raw[key]).is_empty():
			push_error("Wisdom: card '%s' is missing '%s'" % [raw.get("id", "?"), key])
			return {}
	if not Condition.is_well_formed(str(raw["trigger"])):
		push_error("Wisdom: card '%s' has a bad trigger '%s'" % [raw["id"], raw["trigger"]])
		return {}
	return raw.duplicate(true)


## Every card id, in the order the data lists them (the GDD's order).
static func ids() -> PackedStringArray:
	_load()
	return _order.duplicate()


static func has(id: String) -> bool:
	_load()
	return _cards.has(id)


## The card's row, or an empty dictionary for an unknown id.
static func card(id: String) -> Dictionary:
	_load()
	return _cards.get(id, {})


## The condition a card waits on; "false" for an unknown id.
static func trigger_of(id: String) -> String:
	return str(card(id).get("trigger", "false"))


## The ids of the cards whose trigger reads [param flag], in data order. A
## card is offered only at the moment its own flag is set (GDD §9: "tied to
## a beat the player has just lived through"), so a flag change asks for
## exactly these.
static func cards_for_flag(flag: String) -> PackedStringArray:
	_load()
	var out := PackedStringArray()
	for id in _order:
		if Condition.referenced_names(trigger_of(id), Condition.FLAG_PREFIX).has(flag):
			out.append(id)
	return out


## Whether the card's trigger holds against the journey's flags and events.
static func is_triggered(id: String, flags: FlagStore, events: FlagStore) -> bool:
	if not has(id):
		return false
	return Condition.evaluate(trigger_of(id), flags, events)


## The four string ids a card renders, for tests and the data check.
static func string_ids(id: String) -> PackedStringArray:
	var out := PackedStringArray()
	var row := card(id)
	for field in STRING_FIELDS:
		out.append(str(row.get(field, "")))
	return out


## Every flag any trigger reads, sorted and unique, for the debug panel.
static func known_flags() -> PackedStringArray:
	_load()
	var seen: Dictionary = {}
	for id in _order:
		for flag in Condition.referenced_names(trigger_of(id), Condition.FLAG_PREFIX):
			seen[flag] = true
	var out := PackedStringArray(seen.keys())
	out.sort()
	return out
