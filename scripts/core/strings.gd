## Resolves every player-facing string from data, keyed by string id.
##
## CLAUDE_CODE_BRIEF.md §5: "No text baked into scenes." Every label, card and
## line of dialogue resolves through here, so adding a language (GDD §11
## "Localization") means adding a locale file, never touching a scene.
extends Node

const STRINGS_DIR := "res://data/strings/"
const DEFAULT_LOCALE := "en"

var _locale: String = DEFAULT_LOCALE
var _table: Dictionary = {}


func _ready() -> void:
	load_locale(DEFAULT_LOCALE)


## Returns the string for [param id]. A missing id returns a bracketed marker
## rather than an empty string, so it fails visibly in a playtest.
func t(id: String) -> String:
	if _table.has(id):
		return str(_table[id])
	push_warning("Strings: missing id '%s' in locale '%s'" % [id, _locale])
	return "[%s]" % id


func has_id(id: String) -> bool:
	return _table.has(id)


func get_locale() -> String:
	return _locale


func id_count() -> int:
	return _table.size()


## Loads a locale table. Returns false and keeps the current table when the
## file is missing or malformed, so a bad locale can never blank the UI.
func load_locale(locale: String) -> bool:
	var path: String = STRINGS_DIR + locale + ".json"
	var parsed: Variant = read_json_file(path)
	if not parsed is Dictionary:
		push_error("Strings: could not load locale table at %s" % path)
		return false
	_table = parsed
	_locale = locale
	return true


## Reads and parses a JSON file. Returns null on any failure; callers decide
## what a failure means. Shared by the string, quest and dialogue loaders so
## there is one place that knows how data files are read.
static func read_json_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("read_json_file: no file at %s" % path)
		return null
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_error("read_json_file: empty file at %s" % path)
		return null
	var json := JSON.new()
	var error: int = json.parse(text)
	if error != OK:
		push_error(
			(
				"read_json_file: %s line %d: %s"
				% [path, json.get_error_line(), json.get_error_message()]
			)
		)
		return null
	return json.data
