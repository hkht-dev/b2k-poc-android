## A set of named flags. The only thing the game is ever conditional on.
##
## GDD §12 "Flag model": flags are strings in a set; branching dialogue reads
## them; nothing else in the game is conditional on anything but flags and the
## current beat. There is deliberately no value, no counter and no score here —
## a flag is set or it is not.
class_name FlagStore
extends RefCounted

## Emitted after a flag changes. Not emitted when a set flag is set again or a
## clear flag is cleared again, so listeners only hear real transitions.
signal changed(flag: String, is_set: bool)

var _flags: Dictionary = {}


## Sets [param flag]. Returns true only if it was not already set.
func set_flag(flag: String) -> bool:
	if flag.is_empty() or _flags.has(flag):
		return false
	_flags[flag] = true
	changed.emit(flag, true)
	return true


## Clears [param flag]. Returns true only if it was set.
func clear_flag(flag: String) -> bool:
	if not _flags.has(flag):
		return false
	_flags.erase(flag)
	changed.emit(flag, false)
	return true


func has(flag: String) -> bool:
	return _flags.has(flag)


func size() -> int:
	return _flags.size()


## Every set flag, sorted, so a debug listing and a save file are stable.
func all() -> PackedStringArray:
	var names := PackedStringArray(_flags.keys())
	names.sort()
	return names


## Replaces the whole set without emitting per-flag signals. For loading a
## save, where nothing should react flag by flag to state that already was.
func replace_all(flags: PackedStringArray) -> void:
	_flags.clear()
	for flag in flags:
		if not flag.is_empty():
			_flags[flag] = true


func clear_all() -> void:
	replace_all(PackedStringArray())
