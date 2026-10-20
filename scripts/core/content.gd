## Loads every quest and the dialogue table from data/ at boot and binds them
## to the journey.
##
## A designer edits a text file, not code (GDD §6 "Quests"). A file that will
## not parse is reported here, once, by name, and the rest still load.
##
## Registered as the autoload `Content`, after `Strings` and `GameState`.
extends Node

const QUESTS_DIR := "res://data/quests/"
const DIALOGUE_DIR := "res://data/dialogue/"

var quests: Dictionary = {}
var dialogue: Dialogue = null


func _ready() -> void:
	load_all()


func load_all() -> void:
	quests.clear()
	for path in _json_files(QUESTS_DIR):
		var parsed: Variant = Strings.read_json_file(path)
		if not parsed is Dictionary:
			continue
		var quest := Quest.from_dict(parsed, path)
		if quest == null:
			continue
		if quests.has(quest.id):
			push_error("Content: two quests share the id '%s'" % quest.id)
			continue
		quests[quest.id] = quest
		quest.attach(GameState)

	var dialogue_path := DIALOGUE_DIR + Strings.get_locale() + ".json"
	var parsed_dialogue: Variant = Strings.read_json_file(dialogue_path)
	if parsed_dialogue is Dictionary:
		dialogue = Dialogue.from_dict(parsed_dialogue, dialogue_path)
	if dialogue == null:
		push_error("Content: no usable dialogue at %s" % dialogue_path)
		dialogue = Dialogue.from_dict({}, dialogue_path)
	dialogue.attach(GameState)


func quest(id: String) -> Quest:
	return quests.get(id)


func quest_ids() -> PackedStringArray:
	var ids := PackedStringArray(quests.keys())
	ids.sort()
	return ids


## Every flag any data file mentions, plus every flag currently set, sorted and
## unique. The debug panel lists exactly this (CLAUDE_CODE_BRIEF.md §0 item 6).
func known_flags() -> PackedStringArray:
	var names := PackedStringArray()
	for id in quests:
		names.append_array(quests[id].known_flags())
	names.append_array(dialogue.known_flags())
	names.append_array(GameState.flags.all())
	# The expansion's data files (docs/DECISIONS.md "The world grows").
	names.append_array(Garden.known_flags())
	names.append_array(Wisdom.known_flags())
	names.append_array(Tales.known_flags())
	return _unique_sorted(names)


func known_events() -> PackedStringArray:
	var names := PackedStringArray()
	for id in quests:
		names.append_array(quests[id].known_events())
	names.append_array(GameState.events.all())
	return _unique_sorted(names)


static func _json_files(dir_path: String) -> PackedStringArray:
	var paths := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("Content: cannot open %s" % dir_path)
		return paths
	for name in dir.get_files():
		if name.ends_with(".json"):
			paths.append(dir_path + name)
	paths.sort()
	return paths


static func _unique_sorted(names: PackedStringArray) -> PackedStringArray:
	var seen: Dictionary = {}
	for name in names:
		if not name.is_empty():
			seen[name] = true
	var out := PackedStringArray(seen.keys())
	out.sort()
	return out
