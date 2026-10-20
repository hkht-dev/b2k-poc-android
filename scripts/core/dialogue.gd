## Dialogue lines as data, and the runner that walks a conversation.
##
## CLAUDE_CODE_BRIEF.md §5: a line is { speaker, text_id, cards[] (text_id,
## sets, next), requires[], review_status }. Every line carries a review_status
## (GDD §8). A line may also carry its own `sets`, applied when it is shown, so
## a line with no cards — the fountain saying it is dry — can still leave a
## mark. Text never lives here: text_id resolves through the string table.
class_name Dialogue
extends RefCounted

## A line is on screen. Whoever shows cards listens to this.
signal line_shown(line_id: String, line: Dictionary)
## The conversation is over, by a card with no `next`, a dismissed line, or a
## next line whose `requires` are not met.
signal finished

const REVIEW_STATUSES := ["draft", "panel_approved", "final"]
const LINE_REQUIRED := ["speaker", "text_id", "cards", "review_status"]
const CARD_REQUIRED := ["text_id", "next"]

var _lines: Dictionary = {}
var _state: Node = null
var _current := ""


## Builds the table from parsed JSON. Returns null, with the reason pushed as
## an error naming [param source], when any line is not usable.
static func from_dict(data: Dictionary, source: String) -> Dialogue:
	var table := Dialogue.new()
	if not table.add_lines(data, source):
		return null
	return table


## Adds lines, in the same shape, to a table already built: the dawn
## vignettes carry their own lines (GDD §16a) and show them through the one
## running Dialogue, so the cards need no second runner. A card may point at
## a line being added or at one already in the table; a line id already in
## the table is replaced, so adding the same lines twice is harmless. Returns
## false, with the reason pushed as an error naming [param source], and adds
## nothing, when any line is not usable.
func add_lines(data: Dictionary, source: String) -> bool:
	var parsed: Dictionary = {}
	for line_id in data:
		var line := _line(data[line_id], str(line_id), source)
		if line.is_empty():
			return false
		parsed[str(line_id)] = line
	for line_id in parsed:
		for card in parsed[line_id]["cards"]:
			var next: String = card["next"]
			if not next.is_empty() and not parsed.has(next) and not _lines.has(next):
				push_error(
					"Dialogue %s: '%s' points at missing line '%s'" % [source, line_id, next]
				)
				return false
	for line_id in parsed:
		_lines[line_id] = parsed[line_id]
	return true


# -- table --------------------------------------------------------------------


func has_line(line_id: String) -> bool:
	return _lines.has(line_id)


func get_line(line_id: String) -> Dictionary:
	return _lines.get(line_id, {})


func line_ids() -> PackedStringArray:
	var ids := PackedStringArray(_lines.keys())
	ids.sort()
	return ids


## A line is available when every flag it requires is set.
func is_available(line_id: String, flags: FlagStore) -> bool:
	var line := get_line(line_id)
	if line.is_empty():
		return false
	for flag in line["requires"]:
		if not flags.has(flag):
			return false
	return true


## Every flag the dialogue reads or sets, for the debug panel's listing.
func known_flags() -> PackedStringArray:
	var names := PackedStringArray()
	for line_id in _lines:
		var line: Dictionary = _lines[line_id]
		names.append_array(line["requires"])
		names.append_array(line["sets"])
		for card in line["cards"]:
			names.append_array(card["sets"])
	return names


# -- runner -------------------------------------------------------------------


func attach(state: Node) -> void:
	_state = state


## Opens the conversation at [param line_id]. Returns false, and shows nothing,
## when the line does not exist or its requirements are not met.
func start(line_id: String) -> bool:
	if _state == null:
		push_error("Dialogue: start() before attach()")
		return false
	if not is_available(line_id, _state.flags):
		return false
	_show(line_id)
	return true


func current_line_id() -> String:
	return _current


func is_running() -> bool:
	return not _current.is_empty()


## The player tapped card [param index] on the current line.
func choose(index: int) -> void:
	if _current.is_empty():
		return
	var line := get_line(_current)
	if index < 0 or index >= line["cards"].size():
		push_error("Dialogue: line '%s' has no card %d" % [_current, index])
		return
	var card: Dictionary = line["cards"][index]
	_state.record_choice(_current, index, card["sets"])
	for flag in card["sets"]:
		_state.set_flag(flag)
	var next: String = card["next"]
	if next.is_empty() or not is_available(next, _state.flags):
		_finish()
		return
	_show(next)


## The player dismissed a line that offered no cards.
func dismiss() -> void:
	if _current.is_empty():
		return
	_finish()


func _show(line_id: String) -> void:
	_current = line_id
	var line := get_line(line_id)
	for flag in line["sets"]:
		_state.set_flag(flag)
	line_shown.emit(line_id, line)


func _finish() -> void:
	_current = ""
	finished.emit()


# -- parsing ------------------------------------------------------------------


static func _line(raw: Variant, line_id: String, source: String) -> Dictionary:
	if not raw is Dictionary:
		push_error("Dialogue %s: line '%s' is not an object" % [source, line_id])
		return {}
	for key in LINE_REQUIRED:
		if not raw.has(key):
			push_error("Dialogue %s: line '%s' missing '%s'" % [source, line_id, key])
			return {}
	var status := str(raw["review_status"])
	if not REVIEW_STATUSES.has(status):
		push_error("Dialogue %s: line '%s' has review_status '%s'" % [source, line_id, status])
		return {}
	var cards: Array[Dictionary] = []
	for raw_card in raw["cards"]:
		if not raw_card is Dictionary:
			push_error(
				"Dialogue %s: line '%s' has a card that is not an object" % [source, line_id]
			)
			return {}
		for key in CARD_REQUIRED:
			if not raw_card.has(key):
				push_error("Dialogue %s: line '%s' card missing '%s'" % [source, line_id, key])
				return {}
		(
			cards
			. append(
				{
					"text_id": str(raw_card["text_id"]),
					"sets": _strings(raw_card.get("sets", [])),
					"next": str(raw_card["next"]),
				}
			)
		)
	if cards.size() > 3:
		push_error(
			(
				"Dialogue %s: line '%s' offers %d cards; GDD §6 allows two or three"
				% [source, line_id, cards.size()]
			)
		)
		return {}
	return {
		"id": line_id,
		"speaker": str(raw["speaker"]),
		"text_id": str(raw["text_id"]),
		"sets": _strings(raw.get("sets", [])),
		"cards": cards,
		"requires": _strings(raw.get("requires", [])),
		"review_status": status,
	}


static func _strings(value: Variant) -> PackedStringArray:
	var out := PackedStringArray()
	if value is Array:
		for item in value:
			out.append(str(item))
	return out
