## Tests the string table loader.
##
## CLAUDE_CODE_BRIEF.md §5 requires every player-facing string to live in data.
## These tests hold that line: the ids the P0 title screen renders must resolve,
## and a missing id must fail visibly rather than render as empty space.
extends GutTest

const STRINGS_SCRIPT := preload("res://scripts/core/strings.gd")


func test_default_locale_loads() -> void:
	assert_eq(Strings.get_locale(), "en", "the default locale is English")
	assert_gt(Strings.id_count(), 0, "the English table is not empty")


func test_title_screen_ids_resolve() -> void:
	for id: String in ["app.title", "title.begin", "title.build_label"]:
		assert_true(Strings.has_id(id), "the title screen needs the id '%s'" % id)


func test_missing_id_returns_visible_marker() -> void:
	var missing: String = Strings.t("no.such.id")
	assert_eq(missing, "[no.such.id]", "a missing id is bracketed, never blank")


func test_read_json_file_rejects_a_missing_path() -> void:
	var parsed: Variant = STRINGS_SCRIPT.read_json_file("res://data/strings/no_such_locale.json")
	assert_null(parsed, "a missing data file parses to null")
