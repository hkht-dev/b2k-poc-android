## The outfits the player can try on, in order, from data/outfits.json.
##
## Owner request 2026-10-20: "go to showroom and try on different clothes".
## An outfit is an id, a name string id and a skin texture for the one body
## every human wears (scripts/characters/character_rig.gd). The journey
## remembers the id (GameState.outfit), never a texture path, so skins can
## move. Read once and cached, like Places. tools/check_data.py should check
## every entry's skin exists, its name id is in the string table and the
## default is one of the entries.
##
## PLACEHOLDER: the skins are Kenney's CC0 character textures
## (docs/RIGHTS_REGISTER.md), stand-ins for the hand-painted cloth of GDD §10.
class_name Outfits
extends RefCounted

const PATH := "res://data/outfits.json"

static var _order := PackedStringArray()
static var _table: Dictionary = {}
static var _default := ""
static var _loaded := false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	var parsed: Variant = Strings.read_json_file(PATH)
	if not parsed is Dictionary:
		push_error("Outfits: %s did not load" % PATH)
		return
	_default = str(parsed.get("default", ""))
	for entry in parsed.get("outfits", []):
		if not entry is Dictionary or not entry.has("id"):
			push_error("Outfits: an entry in %s has no id" % PATH)
			continue
		var outfit_id := str(entry["id"])
		if _table.has(outfit_id):
			push_error("Outfits: duplicate id '%s' in %s" % [outfit_id, PATH])
			continue
		_order.append(outfit_id)
		_table[outfit_id] = entry


## Every outfit id, in the order the data lists them: the wardrobe's order.
static func ids() -> PackedStringArray:
	_load()
	return _order.duplicate()


static func has(outfit_id: String) -> bool:
	_load()
	return _table.has(outfit_id)


## The outfit a fresh journey wears: the skin on Player.tscn.
static func default_id() -> String:
	_load()
	return _default


static func name_id_of(outfit_id: String) -> String:
	return str(_entry(outfit_id).get("name_id", ""))


static func skin_path_of(outfit_id: String) -> String:
	return str(_entry(outfit_id).get("skin", ""))


## The skin of an outfit, or null for "" and for an id the data does not know
## (a journey saved by a later build): the caller keeps the skin it has.
static func skin_of(outfit_id: String) -> Texture2D:
	var path := skin_path_of(outfit_id)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func _entry(outfit_id: String) -> Dictionary:
	_load()
	var entry: Variant = _table.get(outfit_id)
	return entry if entry is Dictionary else {}
